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

  ## Customizing the ETS Table

  There are two ways to use a custom table name:

  1. Configure the default table name globally:

  ```elixir
  # In your config.exs
  config :pike, :ets_table_name, :my_custom_table_name
  ```

  2. Create a parameterized store with the `use` macro:

  ```elixir
  defmodule MyApp.CustomStore do
    use Pike.Store.ETS, table_name: :my_custom_table
  end

  # Then configure Pike to use it
  config :pike, store: MyApp.CustomStore
  ```

  This approach allows multiple Pike instances with separate ETS tables.
  """

  @doc false
  defmacro __using__(opts) do
    table_name = Keyword.get(opts, :table_name)

    quote do
      @behaviour Pike.Store

      # Use provided table name or fall back to module name
      @table unquote(table_name) || :"#{__MODULE__}_keys"

      def init(opts \\ []) do
        table_opts =
          Keyword.get(opts, :table_opts, [:named_table, :set, :public, read_concurrency: true])

        :ets.new(@table, table_opts)
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

      # Allow direct access to the table name
      def table_name, do: @table
    end
  end
end
