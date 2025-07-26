defmodule Pike.AuthorizationPlugTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn
  
  # Store with test keys
  defmodule TestStore do
    use Pike.Store.ETS, table_name: :plug_test_keys
  end
  
  # Test responder that captures failure reasons
  defmodule TestResponder do
    @behaviour Pike.Responder
    
    def auth_failed(conn, reason) do
      conn
      |> Plug.Conn.put_private(:auth_failure_reason, reason)
      |> Plug.Conn.send_resp(401, "auth failed: #{reason}")
      |> Plug.Conn.halt()
    end
  end
  
  setup do
    TestStore.init()
    
    # Insert test keys
    TestStore.insert(%{
      key: "test_key", 
      permissions: [%{resource: "TestResource", scopes: [:read]}]
    })
    
    TestStore.insert(%{
      key: "disabled_key",
      enabled: false,
      permissions: []
    })
    
    on_exit(fn -> 
      if :ets.info(:plug_test_keys) != :undefined do
        :ets.delete_all_objects(:plug_test_keys)
      end
    end)
    
    :ok
  end
  
  describe "header parsing" do
    test "extracts token from Bearer authorization header" do
      conn = 
        conn(:get, "/")
        |> put_req_header("authorization", "Bearer test_key")
        |> Pike.AuthorizationPlug.call(%{
          store: TestStore,
          assign_to: :pike_api_key,
          on_auth_failure: {Pike.Responder.Default, :auth_failed}
        })
        
      assert conn.assigns[:pike_api_key].key == "test_key"
    end
    
    test "handles case-insensitive Bearer scheme" do
      conn = 
        conn(:get, "/")
        |> put_req_header("authorization", "Bearer test_key")
        |> Pike.AuthorizationPlug.call(%{
          store: TestStore,
          assign_to: :pike_api_key,
          on_auth_failure: {Pike.Responder.Default, :auth_failed}
        })
        
      assert conn.assigns[:pike_api_key].key == "test_key"
    end
    
    test "fails on non-Bearer authorization scheme" do
      conn = 
        conn(:get, "/")
        |> put_req_header("authorization", "Basic dGVzdDp0ZXN0")
        |> Pike.AuthorizationPlug.call(%{
          store: TestStore,
          on_auth_failure: {TestResponder, :auth_failed}
        })
        
      assert conn.halted
      assert conn.private[:auth_failure_reason] == :not_found
    end
    
    test "fails when no token is provided in Bearer header" do
      conn = 
        conn(:get, "/")
        |> put_req_header("authorization", "Bearer ")
        |> Pike.AuthorizationPlug.call(%{
          store: TestStore,
          on_auth_failure: {TestResponder, :auth_failed}
        })
        
      assert conn.halted
      assert conn.private[:auth_failure_reason] == :not_found
    end
  end
  
  describe "configuration options" do
    test "uses custom assign location" do
      conn = 
        conn(:get, "/")
        |> put_req_header("authorization", "Bearer test_key")
        |> Pike.AuthorizationPlug.call(%{
          store: TestStore,
          assign_to: :custom_location
        })
        
      assert conn.assigns[:custom_location].key == "test_key"
      refute Map.has_key?(conn.assigns, :pike_api_key)
    end
    
    test "uses custom responder" do
      conn = 
        conn(:get, "/")
        |> Pike.AuthorizationPlug.call(%{
          store: TestStore,
          on_auth_failure: {TestResponder, :auth_failed}
        })
        
      assert conn.halted
      assert conn.private[:auth_failure_reason] == :missing_key
      assert conn.status == 401
      assert conn.resp_body == "auth failed: missing_key"
    end
  end
  
  describe "request pipeline" do
    test "rejects invalid key" do
      conn = 
        conn(:get, "/")
        |> put_req_header("authorization", "Bearer invalid_key")
        |> Pike.AuthorizationPlug.call(%{
          store: TestStore,
          on_auth_failure: {TestResponder, :auth_failed}
        })
        
      assert conn.halted
      assert conn.private[:auth_failure_reason] == :not_found
    end
    
    test "rejects disabled key" do
      conn = 
        conn(:get, "/")
        |> put_req_header("authorization", "Bearer disabled_key")
        |> Pike.AuthorizationPlug.call(%{
          store: TestStore,
          on_auth_failure: {TestResponder, :auth_failed}
        })
        
      assert conn.halted
      assert conn.private[:auth_failure_reason] == :disabled
    end
    
    test "passes valid key to downstream plugs" do
      # Create a pipeline of plugs
      defmodule TestPipeline do
        use Plug.Builder
        
        plug Pike.AuthorizationPlug, 
          store: TestStore,
          assign_to: :pike_api_key
          
        plug :verify_key
        
        def verify_key(conn, _opts) do
          key = conn.assigns.pike_api_key
          Plug.Conn.assign(conn, :key_verified, key.key == "test_key")
        end
      end
      
      conn = 
        conn(:get, "/")
        |> put_req_header("authorization", "Bearer test_key")
        |> TestPipeline.call([])
        
      refute conn.halted
      assert conn.assigns[:pike_api_key].key == "test_key"
      assert conn.assigns[:key_verified] == true
    end
  end
end