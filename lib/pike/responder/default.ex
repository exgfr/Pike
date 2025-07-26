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
        send_resp(conn, 401, "Missing API key") |> halt()

      :invalid_format ->
        send_resp(conn, 400, "Invalid API key format") |> halt()

      :not_found ->
        send_resp(conn, 403, "API key not found") |> halt()

      :disabled ->
        send_resp(conn, 403, "API key disabled") |> halt()

      :expired ->
        send_resp(conn, 403, "API key expired") |> halt()

      :unauthorized_resource ->
        send_resp(conn, 403, "Unauthorized resource access") |> halt()

      :unauthorized_action ->
        send_resp(conn, 403, "Unauthorized action") |> halt()

      :store_error ->
        send_resp(conn, 500, "Internal authorization error") |> halt()

      _ ->
        send_resp(conn, 403, "Access denied") |> halt()
    end
  end
end
