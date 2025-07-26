defmodule Pike.ApiTest do
  use ExUnit.Case, async: false

  # Define test store for API key management
  defmodule TestStore do
    use Pike.Store.ETS, table_name: :api_test_keys
  end

  # Create a simple API for testing
  defmodule Api do
    def insert(key_data), do: TestStore.insert(key_data)
    def get_key(key), do: TestStore.get_key(key)
    def delete_key(key), do: TestStore.delete_key(key)
    def update_key(key, updates), do: TestStore.update_key(key, updates)

    def action?(key_struct, opts) do
      resource = Keyword.fetch!(opts, :resource)
      action = Keyword.fetch!(opts, :action)
      TestStore.action?(key_struct, resource, action)
    end

    def enable_key(key) do
      update_key(key, %{enabled: true})
    end

    def disable_key(key) do
      update_key(key, %{enabled: false})
    end

    def key_enabled?(key) do
      case get_key(key) do
        {:ok, %{enabled: false}} -> false
        {:ok, _} -> true
        _ -> false
      end
    end
  end

  # Helper for safely deleting objects
  defp safe_delete_all_objects(table) do
    try do
      if :ets.info(table) != :undefined do
        :ets.delete_all_objects(table)
      end
    rescue
      _ -> :ok
    catch
      _ -> :ok
    end
  end

  setup do
    # Initialize the store
    TestStore.init()

    # Clean up after each test
    on_exit(fn ->
      safe_delete_all_objects(:api_test_keys)
    end)

    :ok
  end

  describe "API key creation" do
    test "can create a basic API key" do
      key_data = %{
        key: "basic123",
        permissions: [
          %{resource: "Products", scopes: [:read]}
        ]
      }

      assert :ok = Api.insert(key_data)
      assert {:ok, stored_key} = Api.get_key("basic123")
      assert stored_key.key == "basic123"
      # Default value
      assert stored_key.enabled == true
    end

    test "can create a key with multiple permissions" do
      key_data = %{
        key: "multi_perm",
        permissions: [
          %{resource: "Products", scopes: [:read, :write]},
          %{resource: "Orders", scopes: [:read]},
          %{resource: "Users", scopes: [:admin]}
        ]
      }

      assert :ok = Api.insert(key_data)
      assert {:ok, stored_key} = Api.get_key("multi_perm")

      # Verify all permissions were stored
      assert length(stored_key.permissions) == 3

      # Find specific permissions
      product_perm = Enum.find(stored_key.permissions, fn p -> p.resource == "Products" end)
      assert :read in product_perm.scopes
      assert :write in product_perm.scopes

      order_perm = Enum.find(stored_key.permissions, fn p -> p.resource == "Orders" end)
      assert :read in order_perm.scopes
      assert :write not in order_perm.scopes
    end

    test "can create a disabled key" do
      key_data = %{
        key: "disabled_key",
        enabled: false,
        permissions: [
          %{resource: "Products", scopes: [:read]}
        ]
      }

      assert :ok = Api.insert(key_data)
      assert {:error, :disabled} = Api.get_key("disabled_key")
    end
  end

  describe "API key validation" do
    test "validates key existence" do
      assert :error = Api.get_key("nonexistent")
    end

    test "validates key permissions" do
      key_data = %{
        key: "perm_test",
        permissions: [
          %{resource: "Products", scopes: [:read]},
          %{resource: "Orders", scopes: [:write]}
        ]
      }

      # Insert the key
      Api.insert(key_data)
      {:ok, key} = Api.get_key("perm_test")

      # Test permissions
      assert Api.action?(key, resource: "Products", action: :read) == true
      assert Api.action?(key, resource: "Products", action: :write) == false
      assert Api.action?(key, resource: "Orders", action: :write) == true
      assert Api.action?(key, resource: "Users", action: :read) == false
    end

    test "handles disabled keys correctly" do
      # Create an enabled key
      Api.insert(%{
        key: "toggle_key",
        permissions: [%{resource: "Products", scopes: [:read]}]
      })

      # Key should work initially
      {:ok, key} = Api.get_key("toggle_key")
      assert Api.action?(key, resource: "Products", action: :read) == true

      # Disable the key
      Api.disable_key("toggle_key")

      # Should return disabled error
      assert {:error, :disabled} = Api.get_key("toggle_key")

      # Re-enable the key
      Api.enable_key("toggle_key")

      # Should work again
      {:ok, key} = Api.get_key("toggle_key")
      assert Api.action?(key, resource: "Products", action: :read) == true
    end
  end

  describe "API key deletion" do
    test "can delete keys" do
      # Create a key
      Api.insert(%{
        key: "delete_me",
        permissions: [%{resource: "Test", scopes: [:read]}]
      })

      # Key should exist
      assert {:ok, _} = Api.get_key("delete_me")

      # Delete the key
      assert :ok = Api.delete_key("delete_me")

      # Key should be gone
      assert :error = Api.get_key("delete_me")
    end
  end

  describe "API key updates" do
    test "can update key permissions" do
      # Create initial key
      Api.insert(%{
        key: "update_me",
        permissions: [%{resource: "Products", scopes: [:read]}]
      })

      # Update the key with new permissions
      Api.update_key("update_me", %{
        permissions: [
          %{resource: "Products", scopes: [:read, :write]},
          %{resource: "Orders", scopes: [:read]}
        ]
      })

      # Check that permissions were updated
      {:ok, key} = Api.get_key("update_me")

      assert Enum.any?(key.permissions, fn p ->
               p.resource == "Products" && :write in p.scopes
             end)

      assert Enum.any?(key.permissions, fn p ->
               p.resource == "Orders" && :read in p.scopes
             end)
    end

    test "updates fail for non-existent keys" do
      assert {:error, :not_found} = Api.update_key("missing_key", %{enabled: false})
    end
  end

  describe "key enabled status" do
    test "key_enabled? returns correct status" do
      # Create test keys
      Api.insert(%{key: "enabled_key", permissions: []})
      Api.insert(%{key: "disabled_key", enabled: false, permissions: []})

      assert Api.key_enabled?("enabled_key") == true
      assert Api.key_enabled?("disabled_key") == false
      assert Api.key_enabled?("nonexistent_key") == false
    end
  end
end
