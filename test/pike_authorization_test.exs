defmodule Pike.AuthorizationTest do
  use ExUnit.Case, async: false

  # Define test store for authorization
  defmodule TestStore do
    use Pike.Store.ETS, table_name: :auth_test_keys
  end

  # Create a simplified mock controller that mimics Pike.Authorization
  defmodule MockControllers do
    # Product controller with various permissions
    defmodule ProductController do
      # Simplify by directly implementing auth checks

      def index(conn, _params) do
        # Check if key has read permission for Products
        key = conn.assigns[:pike_api_key]

        if has_permission?(key, "Products", :read) do
          Plug.Conn.send_resp(conn, 200, "products index")
        else
          Plug.Conn.send_resp(conn, 403, "unauthorized")
          |> Plug.Conn.halt()
        end
      end

      def create(conn, _params) do
        # Check if key has write permission for Products
        key = conn.assigns[:pike_api_key]

        if has_permission?(key, "Products", :write) do
          Plug.Conn.send_resp(conn, 201, "product created")
        else
          Plug.Conn.send_resp(conn, 403, "unauthorized")
          |> Plug.Conn.halt()
        end
      end

      def meta(conn, _params) do
        # Check if key has read permission for ProductsMeta
        key = conn.assigns[:pike_api_key]

        if has_permission?(key, "ProductsMeta", :read) do
          Plug.Conn.send_resp(conn, 200, "products meta")
        else
          Plug.Conn.send_resp(conn, 403, "unauthorized")
          |> Plug.Conn.halt()
        end
      end

      def admin(conn, _params) do
        # Check if key has admin permission for AdminProducts
        key = conn.assigns[:pike_api_key]

        if has_permission?(key, "AdminProducts", :admin) do
          Plug.Conn.send_resp(conn, 200, "admin products")
        else
          Plug.Conn.send_resp(conn, 403, "unauthorized")
          |> Plug.Conn.halt()
        end
      end

      # Helper to check permissions
      defp has_permission?(nil, _resource, _action), do: false

      defp has_permission?(key, resource, action) do
        Enum.any?(key.permissions, fn
          %{resource: ^resource, scopes: scopes} when is_list(scopes) -> action in scopes
          _ -> false
        end)
      end
    end
  end

  # Helper for checking permissions directly
  defp has_permission?(nil, _resource, _action), do: false

  defp has_permission?(key, resource, action) do
    Enum.any?(key.permissions, fn
      %{resource: ^resource, scopes: scopes} when is_list(scopes) -> action in scopes
      _ -> false
    end)
  end

  # Helper for safely deleting objects
  defp safe_delete_all_objects(table) do
    try do
      if :ets.info(table) != :undefined do
        :ets.delete_all_objects(table)
      end
    rescue
      _ -> :ok
    catch
      _ -> :ok
    end
  end

  # Helpers for plug testing
  defp build_conn do
    Plug.Test.conn(:get, "/")
  end

  defp build_conn_with_token(token) do
    build_conn()
    |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")
  end

  defp assert_unauthorized(conn) do
    assert conn.halted, "Connection expected to be halted, but was not"
    assert conn.status in [401, 403], "Expected status 401 or 403, got #{conn.status}"
  end

  defp assert_authorized(conn) do
    refute conn.halted, "Connection was unexpectedly halted"
    assert conn.status != 401, "Connection has unauthorized status"
    assert conn.status != 403, "Connection has forbidden status"
  end

  setup do
    # Initialize the store
    TestStore.init()

    # Create test API keys
    TestStore.insert(%{
      key: "read_key",
      permissions: [
        %{resource: "Products", scopes: [:read]},
        %{resource: "ProductsMeta", scopes: [:read]},
        %{resource: "Orders", scopes: [:read]}
      ]
    })

    TestStore.insert(%{
      key: "write_key",
      permissions: [
        %{resource: "Products", scopes: [:read, :write]},
        %{resource: "Orders", scopes: [:read, :write]}
      ]
    })

    TestStore.insert(%{
      key: "admin_key",
      permissions: [
        %{resource: "Products", scopes: [:read, :write, :admin]},
        %{resource: "ProductsMeta", scopes: [:read, :write]},
        %{resource: "AdminProducts", scopes: [:admin]},
        %{resource: "Orders", scopes: [:read, :write, :admin]}
      ]
    })

    TestStore.insert(%{
      key: "disabled_key",
      enabled: false,
      permissions: [
        %{resource: "Products", scopes: [:read, :write, :admin]}
      ]
    })

    # Clean up after each test
    on_exit(fn ->
      safe_delete_all_objects(:auth_test_keys)
    end)

    :ok
  end

  describe "basic authorization" do
    test "rejects requests without authorization header" do
      conn =
        build_conn()
        |> Pike.AuthorizationPlug.call(%{
          store: TestStore,
          assign_to: :pike_api_key,
          on_auth_failure: {Pike.Responder.Default, :auth_failed}
        })

      assert_unauthorized(conn)
      assert conn.status == 401
    end

    test "rejects requests with invalid API key" do
      conn =
        build_conn_with_token("invalid_key")
        |> Pike.AuthorizationPlug.call(%{
          store: TestStore,
          assign_to: :pike_api_key,
          on_auth_failure: {Pike.Responder.Default, :auth_failed}
        })

      assert_unauthorized(conn)
      assert conn.status == 403
    end

    test "rejects requests with disabled API key" do
      conn =
        build_conn_with_token("disabled_key")
        |> Pike.AuthorizationPlug.call(%{
          store: TestStore,
          assign_to: :pike_api_key,
          on_auth_failure: {Pike.Responder.Default, :auth_failed}
        })

      assert_unauthorized(conn)
      assert conn.status == 403
    end

    test "accepts requests with valid API key" do
      conn =
        build_conn_with_token("read_key")
        |> Pike.AuthorizationPlug.call(%{
          store: TestStore,
          assign_to: :pike_api_key,
          on_auth_failure: {Pike.Responder.Default, :auth_failed}
        })

      assert_authorized(conn)
      assert conn.assigns.pike_api_key.key == "read_key"
    end
  end

  describe "custom assign" do
    test "assigns API key to custom location" do
      conn =
        build_conn_with_token("read_key")
        |> Pike.AuthorizationPlug.call(%{
          store: TestStore,
          assign_to: :custom_key,
          on_auth_failure: {Pike.Responder.Default, :auth_failed}
        })

      assert_authorized(conn)
      assert conn.assigns.custom_key.key == "read_key"
      refute Map.has_key?(conn.assigns, :pike_api_key)
    end
  end

  describe "controller authorization" do
    test "allows access to actions with appropriate permissions" do
      # Initialize the authorization plug
      plug_opts = %{
        store: TestStore,
        assign_to: :pike_api_key,
        on_auth_failure: {Pike.Responder.Default, :auth_failed}
      }

      # Test read permission
      conn =
        build_conn_with_token("read_key")
        |> Pike.AuthorizationPlug.call(plug_opts)
        |> MockControllers.ProductController.index(%{})

      assert conn.status == 200
      assert conn.resp_body == "products index"

      # Test read permission with append
      conn =
        build_conn_with_token("read_key")
        |> Pike.AuthorizationPlug.call(plug_opts)
        |> MockControllers.ProductController.meta(%{})

      assert conn.status == 200
      assert conn.resp_body == "products meta"

      # Test write permission
      conn =
        build_conn_with_token("write_key")
        |> Pike.AuthorizationPlug.call(plug_opts)
        |> MockControllers.ProductController.create(%{})

      assert conn.status == 201
      assert conn.resp_body == "product created"

      # Test admin permission with override
      conn =
        build_conn_with_token("admin_key")
        |> Pike.AuthorizationPlug.call(plug_opts)
        |> MockControllers.ProductController.admin(%{})

      assert conn.status == 200
      assert conn.resp_body == "admin products"
    end

    test "denies access to actions without appropriate permissions" do
      # Initialize the authorization plug
      plug_opts = %{
        store: TestStore,
        assign_to: :pike_api_key,
        on_auth_failure: {Pike.Responder.Default, :auth_failed}
      }

      # Read key shouldn't have write permission
      conn =
        build_conn_with_token("read_key")
        |> Pike.AuthorizationPlug.call(plug_opts)
        |> MockControllers.ProductController.create(%{})

      assert_unauthorized(conn)

      # Read key shouldn't have admin permission
      conn =
        build_conn_with_token("read_key")
        |> Pike.AuthorizationPlug.call(plug_opts)
        |> MockControllers.ProductController.admin(%{})

      assert_unauthorized(conn)
    end
  end

  # Test for custom responder
  defmodule CustomResponder do
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
    def auth_failed(conn, reason) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(403, ~s({"error":"Unauthorized","code":"#{reason}"}))
      |> halt()
    end
  end

  describe "custom responder" do
    test "returns custom responses for different errors" do
      # Missing key (no Authorization header)
      conn =
        build_conn()
        |> Pike.AuthorizationPlug.call(%{
          store: TestStore,
          assign_to: :pike_api_key,
          on_auth_failure: {CustomResponder, :auth_failed}
        })

      assert conn.status == 401
      assert conn.halted
      assert conn.resp_body == ~s({"error":"Missing API key","code":"missing_key"})

      assert Plug.Conn.get_resp_header(conn, "content-type") == [
               "application/json; charset=utf-8"
             ]

      # Invalid key
      conn =
        build_conn_with_token("invalid_key")
        |> Pike.AuthorizationPlug.call(%{
          store: TestStore,
          assign_to: :pike_api_key,
          on_auth_failure: {CustomResponder, :auth_failed}
        })

      assert conn.status == 403
      assert conn.halted
      assert conn.resp_body == ~s({"error":"Invalid API key","code":"not_found"})

      # Disabled key
      conn =
        build_conn_with_token("disabled_key")
        |> Pike.AuthorizationPlug.call(%{
          store: TestStore,
          assign_to: :pike_api_key,
          on_auth_failure: {CustomResponder, :auth_failed}
        })

      assert conn.status == 403
      assert conn.halted
      assert conn.resp_body == ~s({"error":"API key is disabled","code":"disabled"})
    end
  end

  # Test for multiple pipelines
  defmodule PublicKeyStore do
    use Pike.Store.ETS, table_name: :public_api_keys
  end

  defmodule AdminKeyStore do
    use Pike.Store.ETS, table_name: :admin_api_keys
  end

  describe "multiple pipelines with different stores" do
    setup do
      # Initialize both stores
      PublicKeyStore.init()
      AdminKeyStore.init()

      # Clear the stores before each test
      :ets.delete_all_objects(:public_api_keys)
      :ets.delete_all_objects(:admin_api_keys)

      # Create public API keys
      PublicKeyStore.insert(%{
        key: "public_read",
        permissions: [
          %{resource: "Products", scopes: [:read]},
          %{resource: "Orders", scopes: [:read]}
        ]
      })

      # Create admin API keys
      AdminKeyStore.insert(%{
        key: "admin_key",
        permissions: [
          %{resource: "Products", scopes: [:read, :write, :admin]},
          %{resource: "Orders", scopes: [:read, :write, :admin]},
          %{resource: "AdminProducts", scopes: [:admin]}
        ]
      })

      # This key exists in both stores but with different permissions
      PublicKeyStore.insert(%{
        key: "dual_key",
        permissions: [
          %{resource: "Products", scopes: [:read]}
        ]
      })

      AdminKeyStore.insert(%{
        key: "dual_key",
        permissions: [
          %{resource: "Products", scopes: [:read, :write, :admin]}
        ]
      })

      # Clean up after each test
      on_exit(fn ->
        safe_delete_all_objects(:public_api_keys)
        safe_delete_all_objects(:admin_api_keys)
      end)

      :ok
    end

    test "public pipeline authorizes public keys only" do
      public_pipeline = %{
        store: PublicKeyStore,
        assign_to: :public_api_key,
        on_auth_failure: {Pike.Responder.Default, :auth_failed}
      }

      # Public key should work in public pipeline
      conn =
        build_conn_with_token("public_read")
        |> Pike.AuthorizationPlug.call(public_pipeline)

      assert_authorized(conn)
      assert conn.assigns.public_api_key.key == "public_read"

      # Admin key should fail in public pipeline
      conn =
        build_conn_with_token("admin_key")
        |> Pike.AuthorizationPlug.call(public_pipeline)

      assert_unauthorized(conn)
    end

    test "admin pipeline authorizes admin keys only" do
      admin_pipeline = %{
        store: AdminKeyStore,
        assign_to: :admin_api_key,
        on_auth_failure: {Pike.Responder.Default, :auth_failed}
      }

      # Admin key should work in admin pipeline
      conn =
        build_conn_with_token("admin_key")
        |> Pike.AuthorizationPlug.call(admin_pipeline)

      assert_authorized(conn)
      assert conn.assigns.admin_api_key.key == "admin_key"

      # Public key should fail in admin pipeline
      conn =
        build_conn_with_token("public_read")
        |> Pike.AuthorizationPlug.call(admin_pipeline)

      assert_unauthorized(conn)
    end

    test "keys that exist in both stores have pipeline-specific permissions" do
      public_pipeline = %{
        store: PublicKeyStore,
        assign_to: :public_api_key,
        on_auth_failure: {Pike.Responder.Default, :auth_failed}
      }

      admin_pipeline = %{
        store: AdminKeyStore,
        assign_to: :admin_api_key,
        on_auth_failure: {Pike.Responder.Default, :auth_failed}
      }

      # Check permissions directly from the store to verify our test setup
      {:ok, dual_key_public} = PublicKeyStore.get_key("dual_key")
      assert PublicKeyStore.action?(dual_key_public, "Products", :read) == true

      # Directly test permission check logic
      assert has_permission?(dual_key_public, "Products", :read) == true

      # Use dual_key in public pipeline (only has read permission)
      conn =
        build_conn_with_token("dual_key")
        |> Pike.AuthorizationPlug.call(public_pipeline)

      # Verify key is assigned correctly
      public_key = conn.assigns.public_api_key
      assert public_key.key == "dual_key"

      # Simplified test - just check the Products:read permission directly
      assert has_permission?(public_key, "Products", :read) == true

      # Same key should fail for write in public pipeline
      conn =
        build_conn_with_token("dual_key")
        |> Pike.AuthorizationPlug.call(public_pipeline)

      # Now use the controller
      # Should fail (write)
      conn = MockControllers.ProductController.create(conn, %{})

      assert_unauthorized(conn)

      # But in admin pipeline, the same key has write permission
      # First verify our test setup
      {:ok, dual_key_admin} = AdminKeyStore.get_key("dual_key")
      assert AdminKeyStore.action?(dual_key_admin, "Products", :write) == true

      # Use dual key in admin pipeline
      conn =
        build_conn_with_token("dual_key")
        |> Pike.AuthorizationPlug.call(admin_pipeline)

      # Verify key is assigned correctly
      admin_key = conn.assigns.admin_api_key
      assert admin_key.key == "dual_key"

      # Directly check the permission
      assert has_permission?(admin_key, "Products", :write) == true
    end

    test "each pipeline assigns to its own location" do
      public_pipeline = %{
        store: PublicKeyStore,
        assign_to: :public_api_key,
        on_auth_failure: {Pike.Responder.Default, :auth_failed}
      }

      admin_pipeline = %{
        store: AdminKeyStore,
        assign_to: :admin_api_key,
        on_auth_failure: {Pike.Responder.Default, :auth_failed}
      }

      # Process a request through both pipelines sequentially
      conn =
        build_conn_with_token("dual_key")
        |> Pike.AuthorizationPlug.call(public_pipeline)
        |> Pike.AuthorizationPlug.call(admin_pipeline)

      # Both keys should be assigned
      assert conn.assigns.public_api_key.key == "dual_key"
      assert conn.assigns.admin_api_key.key == "dual_key"

      # But they should have different permissions
      public_perms = conn.assigns.public_api_key.permissions
      admin_perms = conn.assigns.admin_api_key.permissions

      # Check if public permissions only include read
      product_perm_public = Enum.find(public_perms, fn p -> p.resource == "Products" end)
      assert :read in product_perm_public.scopes
      assert :write not in product_perm_public.scopes

      # Check if admin permissions include read, write, admin
      product_perm_admin = Enum.find(admin_perms, fn p -> p.resource == "Products" end)
      assert :read in product_perm_admin.scopes
      assert :write in product_perm_admin.scopes
      assert :admin in product_perm_admin.scopes
    end
  end
end
