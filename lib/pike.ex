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

  @store Application.compile_env(:pike, :store, Pike.Store.ETS)

  @doc """
  Fetches an API key struct from the configured store.
  """
  def get_key(key), do: @store.get_key(key)

  @doc """
  Checks if the key is allowed to perform an action on a resource.
  """
  def action?(key_struct, opts) do
    resource = Keyword.fetch!(opts, :resource)
    action = Keyword.fetch!(opts, :action)
    @store.action?(key_struct, resource, action)
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
  def insert(key_struct) do
    if function_exported?(@store, :insert, 1) do
      @store.insert(key_struct)
    else
      {:error, :insert_not_supported}
    end
  end

  @doc """
  Delete a key from the store (if supported).
  """
  def delete_key(key) do
    if function_exported?(@store, :delete_key, 1) do
      @store.delete_key(key)
    else
      {:error, :delete_not_supported}
    end
  end

  @doc """
  Update an existing key in the store (if supported).
  """
  def update_key(key, updates) do
    if function_exported?(@store, :update_key, 2) do
      @store.update_key(key, updates)
    else
      {:error, :update_not_supported}
    end
  end

  @doc """
  Enable a key that has been disabled.
  """
  def enable_key(key) do
    update_key(key, %{enabled: true})
  end

  @doc """
  Disable a key temporarily without deleting it.
  """
  def disable_key(key) do
    update_key(key, %{enabled: false})
  end

  @doc """
  Check if a key is enabled.
  """
  def key_enabled?(key) do
    case get_key(key) do
      {:ok, %{enabled: false}} -> false
      {:ok, _} -> true
      _ -> false
    end
  end
end
