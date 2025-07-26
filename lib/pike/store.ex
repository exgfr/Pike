defmodule Pike.Store do
  @moduledoc """
  Behaviour module defining the interface for Pike API key stores.

  Any module used as a store in Pike must implement these functions.
  """
  @optional_callbacks [delete_key: 1, update_key: 2]

  @callback get_key(String.t()) :: {:ok, map()} | :error

  @doc """
  Checks if the given key struct permits the specified action on a resource.
  """
  @callback action?(map(), resource :: String.t(), action :: atom()) :: boolean()

  @doc """
  Inserts a key into the store. Used primarily for in-memory stores like ETS.
  """
  @callback insert(map()) :: :ok | {:error, term()}

  @doc """
  Optional: Deletes a key from the store.
  """
  @callback delete_key(String.t()) :: :ok | {:error, term()}

  @doc """
  Optional: Updates a key in the store.
  """
  @callback update_key(String.t(), map()) :: :ok | {:error, term()}
end
