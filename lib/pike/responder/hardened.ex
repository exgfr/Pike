defmodule Pike.Responder.Hardened do
  @moduledoc """
  Hardened responder for Pike authorization failures.

  Provides minimal information for 403 responses to prevent information leakage.
  Maintains more informative responses for 401 and other status codes.
  """

  import Plug.Conn

  @spec auth_failed(Plug.Conn.t(), Pike.Responder.reason()) :: Plug.Conn.t()
  def auth_failed(conn, reason) do
    case reason do
      :missing_key ->
        send_resp(conn, 401, "Authentication required") |> halt()

      :invalid_format ->
        send_resp(conn, 400, "Bad request") |> halt()

      # All 403 responses provide minimal information
      reason when reason in [:not_found, :disabled, :expired, :unauthorized_resource, :unauthorized_action] ->
        send_resp(conn, 403, "Access denied") |> halt()

      :store_error ->
        send_resp(conn, 500, "Server error") |> halt()

      _ ->
        send_resp(conn, 403, "Access denied") |> halt()
    end
  end
end
