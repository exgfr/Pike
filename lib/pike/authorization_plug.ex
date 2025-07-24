defmodule Pike.AuthorizationPlug do
  @moduledoc """
  A Plug to authenticate API requests using API keys.

  Looks for a Bearer token in the `authorization` header.
  Delegates lookup to a configured store.
  Delegates error handling to a configured responder.

  ## Options

    * `:store` - the store module (defaults to `Pike.Store.ETS`)
    * `:assign_to` - where to assign the key in `conn.assigns` (defaults to `:pike_api_key`)
    * `:on_auth_failure` - responder module and function (defaults to `Pike.Responder.Default`)
  """
  import Plug.Conn

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

  defp fail(conn, %{on_auth_failure: {mod, fun}}, reason) do
    apply(mod, fun, [conn, reason])
  end
end
