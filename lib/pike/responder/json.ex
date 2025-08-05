defmodule Pike.Responder.JSON do
  @moduledoc """
  JSON responder for Pike authorization failures.

  Responds with appropriate HTTP status codes and simple json messages
  based on the reason provided.

  ## Error Responses

  | Error Code | HTTP Status | Response Message | Meaning | Troubleshooting |
  |------------|-------------|-----------------|---------|-----------------|
  | `:missing_key` | 401 | "Authentication required" | No Bearer token provided | Check Authorization header exists and contains "Bearer <token>" |
  | `:invalid_format` | 400 | "Authentication invalid" | Token format is incorrect | Verify token format matches required pattern |
  | `:not_found` | 403 | "Authentication failed" | Token doesn't exist in store | Confirm token is registered and hasn't been deleted |
  | `:disabled` | 403 | "Authentication rejected" | Token exists but is disabled | Check if token has been deactivated or blocked |
  | `:expired` | 403 | "Authentication expired" | Token has passed expiration | Renew or request a new token |
  | `:unauthorized_resource` | 403 | "Unauthorized resource" | Missing permission for resource | Verify token has permission for the requested resource |
  | `:unauthorized_action` | 403 | "Unauthorized action" | Missing permission for action | Ensure token has the specific action permission required |
  | `:store_error` | 500 | "Authorization unavailable" | Store error occurred | Check logs for database/store errors |
  | `_` (default) | 403 | "Access denied" | General authorization failure | Review request and permissions |
  """

  import Plug.Conn

  @spec auth_failed(Plug.Conn.t(), Pike.Responder.reason()) :: Plug.Conn.t()
  def auth_failed(conn, reason) do
    {status, message} =
      case reason do
        :missing_key -> {401, "Authentication required"}
        :invalid_format -> {400, "Authentication invalid"}
        :not_found -> {403, "Authentication failed"}
        :disabled -> {403, "Authentication rejected"}
        :expired -> {403, "Authentication expired"}
        :unauthorized_resource -> {403, "Unauthorized resource"}
        :unauthorized_action -> {403, "Unauthorized action"}
        :store_error -> {500, "Authorization unavailable"}
        _ -> {403, "Access denied"}
      end

    json = ~s({"error":"#{escape(message)}"})
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, json)
    |> halt()
  end

  defp escape(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end
end
