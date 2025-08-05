defmodule Pike.Responder.Default do
  @moduledoc """
  Default responder for Pike authorization failures.

  Responds with appropriate HTTP status codes and simple plaintext messages
  based on the reason provided.
  """

  import Plug.Conn

  @spec auth_failed(Plug.Conn.t(), Pike.Responder.reason()) :: Plug.Conn.t()
  def auth_failed(conn, reason) do
    case reason do
      :missing_key ->
        send_resp(conn, 401, "Authentication required") |> halt()

      :invalid_format ->
        send_resp(conn, 400, "Authentication invalid") |> halt()

      :not_found ->
        send_resp(conn, 403, "Authentication failed") |> halt()

      :disabled ->
        send_resp(conn, 403, "Authentication rejected") |> halt()

      :expired ->
        send_resp(conn, 403, "Authentication expired") |> halt()

      :unauthorized_resource ->
        send_resp(conn, 403, "Unauthorized resource") |> halt()

      :unauthorized_action ->
        send_resp(conn, 403, "Unauthorized action") |> halt()

      :store_error ->
        send_resp(conn, 500, "Authorization unavailable") |> halt()

      _ ->
        send_resp(conn, 403, "Access denied") |> halt()
    end
  end
end
