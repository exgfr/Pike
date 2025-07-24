defmodule Pike do
  @moduledoc """
  Pike — Guard at the API Gate

  A lightweight, pluggable API key authentication and authorization system for Elixir applications.
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
