defmodule Pike.Test.CustomResponder do
  @moduledoc """
  Custom responder for testing Pike authorization failure handling.
  """
  @behaviour Pike.Responder

  import Plug.Conn

  @impl true
  def auth_failed(conn, :missing_key) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, ~s({"error":"Missing API key","code":"missing_key"}))
    |> halt()
  end

  @impl true
  def auth_failed(conn, :not_found) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(403, ~s({"error":"Invalid API key","code":"not_found"}))
    |> halt()
  end

  @impl true
  def auth_failed(conn, :disabled) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(403, ~s({"error":"API key is disabled","code":"disabled"}))
    |> halt()
  end

  @impl true
  def auth_failed(conn, :unauthorized_resource) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(403, ~s({"error":"Unauthorized resource","code":"unauthorized_resource"}))
    |> halt()
  end

  @impl true
  def auth_failed(conn, :unauthorized_action) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(403, ~s({"error":"Unauthorized action","code":"unauthorized_action"}))
    |> halt()
  end

  @impl true
  def auth_failed(conn, _reason) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(500, ~s({"error":"Internal authorization error","code":"server_error"}))
    |> halt()
  end
end
