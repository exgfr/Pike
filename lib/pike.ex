defmodule Pike do
  @moduledoc """
  A lightweight, embeddable Elixir library for API key authentication and fine-grained authorization. Pike provides a plug-compatible middleware system and a resource-based DSL for defining authorization rules at the controller and action level.

  ## Authorization Flow

  1. The `Pike.AuthorizationPlug` extracts the Bearer token from the request header
  2. The configured store validates the key and checks permissions
  3. Valid keys are assigned to `conn.assigns[:pike_api_key]` (or custom assign)
  4. The controller's action permission requirements are checked via DSL
  5. Unauthorized requests are handled by the configured responder

  ## Configuration

  Pike can be customized at both the global and per-pipeline level:

  * `store`: The storage backend (default: `Pike.Store.ETS`)
  * `assign_to`: Where to assign the key (default: `:pike_api_key`)
  * `on_auth_failure`: Failure handler (default: `Pike.Responder.Default`)

  """

  @store Application.compile_env(:pike, :store, nil)

  defp store(store) do
    if store do
      store
    else
      raise "Pike store not configured! Please set `:store` in your application config."
    end
  end

  defp store_implements?(function, arity, store) do
    function_exported?(store(store), function, arity)
  end

  @doc """
  Fetches an API key struct from the configured store.
  """
  def get_key(key, store \\ @store), do: store(store).get_key(key)

  @doc """
  Checks if the key is allowed to perform an action on a resource.
  """
  def action?(key_struct, opts, store \\ @store) do
    resource = Keyword.fetch!(opts, :resource)
    action = Keyword.fetch!(opts, :action)
    store(store).action?(key_struct, resource, action)
  end

  @doc """
  Insert a key into the store (if supported).

  Key struct example:
  ```
  %{
    key: "abc123",
    enabled: true,  # Optional, defaults to true
    permissions: [
      %{resource: "Products", scopes: [:read, :write]}
    ]
  }
  ```
  """
  def insert(key_struct, store \\ @store) do
    if store_implements?(:insert, 1, store) do
      store(store).insert(key_struct)
    else
      {:error, :insert_not_supported}
    end
  end

  @doc """
  Delete a key from the store (if supported).
  """
  def delete_key(key, store \\ @store) do
    if store_implements?(:delete_key, 1, store) do
      store(store).delete_key(key)
    else
      {:error, :delete_not_supported}
    end
  end

  @doc """
  Update an existing key in the store (if supported).
  """
  def update_key(key, updates, store \\ @store) do
    if store_implements?(:update_key, 2, store) do
      store(store).update_key(key, updates)
    else
      {:error, :update_not_supported}
    end
  end

  @doc """
  Enable a key that has been disabled.
  """
  def enable_key(key, store \\ @store) do
    update_key(key, %{enabled: true}, store)
  end

  @doc """
  Disable a key temporarily without deleting it.
  """
  def disable_key(key, store \\ @store) do
    update_key(key, %{enabled: false}, store)
  end

  @doc """
  Check if a key is enabled.
  """
  def key_enabled?(key, store \\ @store) do
    case get_key(key, store) do
      {:ok, %{enabled: false}} -> false
      {:ok, _} -> true
      _ -> false
    end
  end
end
