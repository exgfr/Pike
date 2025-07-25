defmodule Pike.AuthorizationPlug do
  @moduledoc """
  A Plug to authenticate API requests using API keys.

  This plug intercepts incoming requests, extracts the Bearer token from the `authorization`
  header, validates it against a configured key store, and assigns the key structure to the
  connection if valid. If authentication fails, it delegates error handling to a configured
  responder.

  ## Features

  * Bearer token extraction from authorization header
  * Configurable key storage backend
  * Customizable authentication failure handling
  * Integration with Pike's permission system

  ## Usage Example

  ```elixir
  # In a Phoenix router
  pipeline :api do
    plug :accepts, ["json"]
    plug Pike.AuthorizationPlug,
      store: MyApp.CustomStore,
      assign_to: :api_key,
      on_auth_failure: {MyApp.ApiResponder, :handle_unauthorized}
  end
  ```

  ## Options

    * `:store` - the storage backend module (defaults to `Pike.Store.ETS`)
    * `:assign_to` - where to assign the key in `conn.assigns` (defaults to `:pike_api_key`)
    * `:on_auth_failure` - responder module and function as a tuple (defaults to `{Pike.Responder.Default, :auth_failed}`)

  ## Error Handling

  The plug handles the following error scenarios:

  * `:missing_key` - No authorization header or Bearer token present
  * `:disabled` - The key exists but is disabled
  * `:not_found` - The key doesn't exist in the store or another error occurred
  """
  import Plug.Conn

  @doc """
  Initializes the plug with provided options or falls back to application configuration.

  ## Parameters

    * `opts` - Keyword list of options:
      * `:store` - Storage backend module
      * `:assign_to` - Connection assign key 
      * `:on_auth_failure` - Responder module and function tuple

  ## Returns

  A map with resolved configuration values that will be passed to `call/2`.
  """
  def init(opts) do
    %{
      store: Keyword.get(opts, :store, Application.get_env(:pike, :store, Pike.Store.ETS)),
      assign_to: Keyword.get(opts, :assign_to, :pike_api_key),
      on_auth_failure:
        Keyword.get(
          opts,
          :on_auth_failure,
          Application.get_env(:pike, :on_auth_failure, {Pike.Responder.Default, :auth_failed})
        )
    }
  end

  @doc """
  Processes the connection by extracting and validating the API key from the request.

  ## Process Flow

  1. Extracts the Bearer token from the authorization header
  2. Validates the token against the configured store
  3. If valid, assigns the key to the connection
  4. If invalid, delegates to the failure handler

  ## Parameters

    * `conn` - The Plug connection
    * `opts` - The options map from `init/1`

  ## Returns

  The connection with the API key assigned or with an error response (halted).
  """
  def call(conn, opts) do
    with ["Bearer " <> raw_key] <- get_req_header(conn, "authorization"),
         {:ok, key_struct} <- opts.store.get_key(raw_key) do
      assign(conn, opts.assign_to, key_struct)
    else
      [] -> fail(conn, opts, :missing_key)
      {:error, :disabled} -> fail(conn, opts, :disabled)
      _ -> fail(conn, opts, :not_found)
    end
  end

  @doc false
  # Handles authentication failures by delegating to the configured responder.
  #
  # ## Parameters
  #
  #   * `conn` - The Plug connection
  #   * `opts` - The options map containing the failure handler
  #   * `reason` - The reason for the failure (atom)
  #
  # ## Returns
  #
  # The connection with an appropriate error response (typically halted).
  defp fail(conn, %{on_auth_failure: {mod, fun}}, reason) do
    apply(mod, fun, [conn, reason])
  end
end
