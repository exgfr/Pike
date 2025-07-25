defmodule Pike.Test.MockControllers do
  @moduledoc """
  Mock controllers for testing Pike authorization.
  """
  
  defmodule ProductController do
    use Pike.Authorization, resource: "Products"
    
    @require_permission action: :read
    def index(conn, _params) do
      Plug.Conn.send_resp(conn, 200, "products index")
    end
    
    @require_permission action: :write
    def create(conn, _params) do
      Plug.Conn.send_resp(conn, 201, "product created")
    end
    
    @require_permission action: :read, append: "Meta"
    def meta(conn, _params) do
      Plug.Conn.send_resp(conn, 200, "products meta")
    end
    
    @require_permission action: :admin, override: "AdminProducts"
    def admin(conn, _params) do
      Plug.Conn.send_resp(conn, 200, "admin products")
    end
  end
  
  defmodule OrderController do
    use Pike.Authorization, resource: "Orders"
    
    @require_permission action: :read
    def index(conn, _params) do
      Plug.Conn.send_resp(conn, 200, "orders index")
    end
    
    @require_permission action: :write
    def create(conn, _params) do
      Plug.Conn.send_resp(conn, 201, "order created")
    end
  end
end