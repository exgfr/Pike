# Using Pike's AuthorizationPlug

This guide covers the various ways to use Pike's `AuthorizationPlug` to authenticate and authorize API requests using Bearer tokens.

## Basic Usage

The simplest way to use Pike's authorization system is to add the plug to your pipeline:

```elixir
# In a Phoenix router
pipeline :api do
  plug :accepts, ["json"]
  plug Pike.AuthorizationPlug
end

scope "/api", MyAppWeb do
  pipe_through :api
  
  resources "/products", ProductController
end
```

This configuration:
1. Extracts the Bearer token from the `Authorization` header
2. Validates the token against the configured store
3. Assigns the authenticated key to `conn.assigns[:pike_api_key]`
4. Rejects unauthorized requests with appropriate status codes

## Configuration Options

The `AuthorizationPlug` accepts several options to customize its behavior:

```elixir
plug Pike.AuthorizationPlug,
  store: MyApp.CustomStore,
  assign_to: :current_api_key,
  on_auth_failure: MyApp.CustomResponder
```

### Available Options

| Option | Description | Default |
|--------|-------------|---------|
| `store` | Module implementing the `Pike.Store` behavior | `Pike.Store.ETS` |
| `assign_to` | The assign key where the API key will be stored | `:pike_api_key` |
| `on_auth_failure` | Module implementing the `Pike.Responder` behavior | `Pike.Responder.Default` |

## Multiple Authorization Pipelines

Pike supports multiple independent authorization pipelines, each with its own configuration:

```elixir
# In a Phoenix router
pipeline :public_api do
  plug :accepts, ["json"]
  plug Pike.AuthorizationPlug, store: MyApp.PublicKeyStore
end

pipeline :admin_api do
  plug :accepts, ["json"]
  plug Pike.AuthorizationPlug, store: MyApp.AdminKeyStore
end

scope "/api/v1", MyAppWeb do
  pipe_through :public_api
  
  resources "/products", ProductV1.ProductController, only: [:index, :show]
end

scope "/api/admin", MyAppWeb do
  pipe_through :admin_api
  
  resources "/products", Admin.ProductController
end
```

This setup allows different API endpoints to use different key stores and authorization rules.

## Using with Controllers

Pike works seamlessly with controllers via the authorization DSL:

```elixir
defmodule MyAppWeb.ProductController do
  use MyAppWeb, :controller
  use Pike.Authorization
  
  use Pike.Authorization, resource: "Products"

  @require_permission action: :read
  def index(conn, _params) do
    # This action requires read permission on Products
    products = MyApp.Catalog.list_products()
    render(conn, "index.json", products: products)
  end
  
  @require_permission action: :read
  def show(conn, %{"id" => id}) do
    # This action requires read permission on Products
    product = MyApp.Catalog.get_product!(id)
    render(conn, "show.json", product: product)
  end
  
  @require_permission action: :write
  def create(conn, %{"product" => product_params}) do
    # This action requires write permission on Products
    # ...
  end
end
```

## Manual Authorization

For more complex scenarios, you can perform manual authorization checks:

```elixir
def custom_action(conn, _params) do
  api_key = conn.assigns[:pike_api_key]
  
  cond do
    Pike.action?(api_key, resource: "Products", action: :admin) ->
      # Handle admin action
      
    Pike.action?(api_key, resource: "Products", action: :read) ->
      # Handle read-only action
      
    true ->
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Insufficient permissions"})
      |> halt()
  end
end
```

## Custom Extraction Logic

If you need custom token extraction logic, you can create your own plug that sets the API key and then use Pike for authorization only:

```elixir
defmodule MyApp.CustomAuthPlug do
  import Plug.Conn
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    # Custom logic to extract and validate token
    # ...
    
    # Assign the validated key to conn
    assign(conn, :pike_api_key, api_key)
  end
end

# In your pipeline
pipeline :api do
  plug :accepts, ["json"]
  plug MyApp.CustomAuthPlug
  # Note: Pike doesn't support skipping extraction directly.
  # Simply assign the key to conn.assigns[:pike_api_key] in your custom plug
  plug Pike.AuthorizationPlug
end
```

## Integration with Authentication Frameworks

Pike can be used alongside other authentication frameworks:

```elixir
pipeline :api do
  plug :accepts, ["json"]
  
  # First authenticate the user
  plug MyApp.Authentication
  
  # Then authorize API access
  plug Pike.AuthorizationPlug
end
```

## Customizing Failure Responses

Implement a custom responder to tailor error responses:

```elixir
defmodule MyApp.CustomResponder do
  @behaviour Pike.Responder
  
  import Plug.Conn
  
  @impl true
  def auth_failed(conn, :missing_key) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{
        error: "Authentication required",
        detail: "Please provide a valid API token"
    })
    |> halt()
  end
  
  @impl true
  def auth_failed(conn, :not_found) do
    # Custom handling for invalid tokens
    # ...
  end
  
  @impl true
  def auth_failed(conn, :unauthorized_action) do
    # Custom handling for valid tokens with insufficient permissions
    # ...
  end
end
```

## Testing with Pike

For testing controllers that use Pike:

```elixir
# In your test setup
setup do
  # Create a test API key with appropriate permissions
  api_key = %{
    key: "test_key_123",
    enabled: true,
    permissions: [
      %{resource: "Products", scopes: [:read, :write]}
    ]
  }
  
  # Insert it into the store
  Pike.insert(api_key)
  
  # Use it in your test connections
  conn = 
    build_conn()
    |> put_req_header("authorization", "Bearer test_key_123")
  
  {:ok, conn: conn}
end
```

By leveraging these various approaches, you can adapt Pike's authorization system to fit the specific needs of your application.