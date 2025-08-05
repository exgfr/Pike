defmodule Pike.Responder.Hardened do
  @moduledoc """
  Hardened responder for Pike authorization failures.

  Provides minimal information for 403 responses to prevent information leakage.
  Maintains more informative responses for 401 and other status codes.

  ## Error Responses

  | Error Code | HTTP Status | Response Message | Security Consideration |
  |------------|-------------|-----------------|------------------------|
  | `:missing_key` | 401 | "Authentication required" | Indicates auth header is missing without revealing implementation details |
  | `:invalid_format` | 400 | "Bad request" | Gives minimal information about format issues |
  | `:not_found` | 403 | "Access denied" | Hides specific reason for 403 errors |
  | `:disabled` | 403 | "Access denied" | Hides specific reason for 403 errors |
  | `:expired` | 403 | "Access denied" | Hides specific reason for 403 errors |
  | `:unauthorized_resource` | 403 | "Access denied" | Hides specific reason for 403 errors |
  | `:unauthorized_action` | 403 | "Access denied" | Hides specific reason for 403 errors |
  | `:store_error` | 500 | "Server error" | Minimal internal error information |
  | `_` (default) | 403 | "Access denied" | Generic denial message |

  Use this responder in production environments where security is a priority over
  detailed error messages. This responder is designed to prevent information leakage
  that could be useful to attackers attempting to enumerate valid API keys or
  permissions.
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
