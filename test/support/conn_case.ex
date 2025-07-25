defmodule Pike.Test.ConnCase do
  @moduledoc """
  Helper module for testing Pike with Plug.Conn.
  """
  
  # Mock a simplified version of the Phoenix.ConnTest module
  # This will let us test plug functionality without Phoenix dependencies
  
  defmacro __using__(_) do
    quote do
      import Plug.Conn
      import Plug.Test
      import Pike.Test.ConnCase
      
      # Import assertion functions from ExUnit
      import ExUnit.Assertions
      
      # Import convenience functions
      alias Plug.Conn
    end
  end
  
  @doc """
  Creates a basic connection for testing.
  """
  def build_conn() do
    Plug.Test.conn(:get, "/")
  end
  
  @doc """
  Creates a connection with a bearer token in the Authorization header.
  """
  def build_conn_with_token(token) do
    build_conn()
    |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")
  end
  
  @doc """
  Shorthand for asserting on connection halted status.
  """
  def assert_unauthorized(conn) do
    assert conn.halted, "Connection expected to be halted, but was not"
    assert conn.status in [401, 403], "Expected status 401 or 403, got #{conn.status}"
  end
  
  @doc """
  Shorthand for asserting on connection authorized status.
  """
  def assert_authorized(conn) do
    refute conn.halted, "Connection was unexpectedly halted"
    assert conn.status != 401, "Connection has unauthorized status"
    assert conn.status != 403, "Connection has forbidden status"
  end
end