defmodule Pike.Store.ETS do
  @moduledoc """
  Default in-memory ETS-based API key store for Pike.

  Stores key structs with permissions like:

      %{
        key: "abc123",
        enabled: true,
        permissions: [
          %{resource: "Products", scopes: [:read, :write]}
        ]
      }
  """
  @behaviour Pike.Store

  @table :pike_api_keys

  def init do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
  rescue
    # already exists
    ArgumentError -> :ok
  end

  def insert(%{key: key} = struct) when is_binary(key) do
    # Ensure the enabled field exists and defaults to true if not provided
    struct = Map.put_new(struct, :enabled, true)
    true = :ets.insert(@table, {key, struct})
    :ok
  end

  def get_key(key) when is_binary(key) do
    case :ets.lookup(@table, key) do
      [{^key, struct}] ->
        case struct do
          %{enabled: false} -> {:error, :disabled}
          _ -> {:ok, struct}
        end

      _ ->
        :error
    end
  end

  def action?(%{permissions: _permissions, enabled: false}, _resource, _action), do: false

  def action?(%{permissions: permissions, enabled: true}, resource, action) do
    Enum.any?(permissions, fn
      %{resource: ^resource, scopes: scopes} when is_list(scopes) -> action in scopes
      _ -> false
    end)
  end

  def action?(%{permissions: permissions}, resource, action) do
    # For backward compatibility with keys that don't have the enabled field
    Enum.any?(permissions, fn
      %{resource: ^resource, scopes: scopes} when is_list(scopes) -> action in scopes
      _ -> false
    end)
  end

  def action?(_, _, _), do: false

  def delete_key(key) when is_binary(key) do
    :ets.delete(@table, key)
    :ok
  end

  def update_key(key, updates) when is_binary(key) and is_map(updates) do
    case :ets.lookup(@table, key) do
      [{^key, struct}] ->
        updated_struct = Map.merge(struct, updates)
        true = :ets.insert(@table, {key, updated_struct})
        :ok

      _ ->
        {:error, :not_found}
    end
  end
end
