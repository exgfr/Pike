defmodule Pike.Store.ETSTest do
  use ExUnit.Case, async: false
  
  # Define custom stores with different table names for testing
  defmodule TestStore do
    use Pike.Store.ETS, table_name: :pike_api_keys
  end
  
  defmodule CustomStore do
    use Pike.Store.ETS, table_name: :custom_api_keys
  end
  
  defmodule AutoNamedStore do
    use Pike.Store.ETS
  end
  
  # Create a helper to safely clean up ETS tables
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
    # Initialize stores and create ETS tables
    TestStore.init()
    CustomStore.init()
    AutoNamedStore.init()
    
    # Clean up after each test
    on_exit(fn ->
      safe_delete_all_objects(:pike_api_keys)
      safe_delete_all_objects(:custom_api_keys)
      safe_delete_all_objects(:"Elixir.Pike.Store.ETSTest.AutoNamedStore_keys")
    end)
    
    :ok
  end
  
  describe "table_name configuration" do
    test "default store uses :pike_api_keys table" do
      assert TestStore.table_name() == :pike_api_keys
    end
    
    test "custom store uses configured table name" do
      assert CustomStore.table_name() == :custom_api_keys
    end
    
    test "auto-named store uses module name as table name" do
      assert AutoNamedStore.table_name() == :"Elixir.Pike.Store.ETSTest.AutoNamedStore_keys"
    end
  end
  
  describe "multiple independent stores" do
    test "each store operates on its own table" do
      # Create key in default store
      default_key = %{key: "default_key", permissions: [%{resource: "Test", scopes: [:read]}]}
      TestStore.insert(default_key)
      
      # Create different key in custom store
      custom_key = %{key: "custom_key", permissions: [%{resource: "Test", scopes: [:write]}]}
      CustomStore.insert(custom_key)
      
      # Create different key in auto-named store
      auto_key = %{key: "auto_key", permissions: [%{resource: "Test", scopes: [:admin]}]}
      AutoNamedStore.insert(auto_key)
      
      # Each store should only find its own keys
      assert {:ok, _} = TestStore.get_key("default_key")
      assert :error = TestStore.get_key("custom_key")
      assert :error = TestStore.get_key("auto_key")
      
      assert :error = CustomStore.get_key("default_key")
      assert {:ok, _} = CustomStore.get_key("custom_key") 
      assert :error = CustomStore.get_key("auto_key")
      
      assert :error = AutoNamedStore.get_key("default_key")
      assert :error = AutoNamedStore.get_key("custom_key")
      assert {:ok, _} = AutoNamedStore.get_key("auto_key")
    end
    
    test "operations on one store don't affect others" do
      # Insert keys in all stores
      key_data = %{key: "same_key", permissions: [%{resource: "Test", scopes: [:read]}]}
      TestStore.insert(key_data)
      CustomStore.insert(key_data)
      AutoNamedStore.insert(key_data)
      
      # All stores should have the key
      assert {:ok, _} = TestStore.get_key("same_key")
      assert {:ok, _} = CustomStore.get_key("same_key")
      assert {:ok, _} = AutoNamedStore.get_key("same_key")
      
      # Delete from one store
      TestStore.delete_key("same_key")
      
      # Only that store should be affected
      assert :error = TestStore.get_key("same_key")
      assert {:ok, _} = CustomStore.get_key("same_key")
      assert {:ok, _} = AutoNamedStore.get_key("same_key")
    end
  end
  
  describe "permission checks in different stores" do
    test "each store handles permissions independently" do
      # Setup different keys with different permissions in each store
      TestStore.insert(%{
        key: "test_key", 
        permissions: [%{resource: "Products", scopes: [:read]}]
      })
      
      CustomStore.insert(%{
        key: "test_key", 
        permissions: [%{resource: "Products", scopes: [:write]}]
      })
      
      AutoNamedStore.insert(%{
        key: "test_key", 
        permissions: [%{resource: "Products", scopes: [:admin]}]
      })
      
      # Test permissions in default store
      {:ok, default_key} = TestStore.get_key("test_key")
      assert TestStore.action?(default_key, "Products", :read) == true
      assert TestStore.action?(default_key, "Products", :write) == false
      
      # Test permissions in custom store
      {:ok, custom_key} = CustomStore.get_key("test_key")
      assert CustomStore.action?(custom_key, "Products", :read) == false
      assert CustomStore.action?(custom_key, "Products", :write) == true
      
      # Test permissions in auto-named store
      {:ok, auto_key} = AutoNamedStore.get_key("test_key")
      assert AutoNamedStore.action?(auto_key, "Products", :admin) == true
      assert AutoNamedStore.action?(auto_key, "Products", :read) == false
    end
  end
end