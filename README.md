# Pike

Pike enables API key enforcement with zero external dependencies, pluggable storage backends, resource-aware permissions, and a flexible DSL for defining authorization at the controller and action level.

---

### Chapters


- [Pike](#pike)
    - [Chapters](#chapters)
  - [Usage](#usage)
    - [Installation](#installation)
    - [Configuration](#configuration)
    - [Using Plug](#using-plug)
      - [🔀 Multiple Pipelines](#-multiple-pipelines)
    - [Controller Integration](#controller-integration)
  - [Permission Model](#permission-model)
  - [Key Assignment](#key-assignment)
  - [Key Management](#key-management)
  - [Store Backend](#store-backend)
  - [🔖 License](#-license)


---

## Usage

### Installation

Add Pike to your dependencies:

```elixir
def deps do
  [
    {:pike, "~> 0.1.0"}
  ]
end
```

### Configuration

Global application-wide config (only needed if overriding defaults):

```elixir
config :pike,
  store: YourApp.APIStore,
  on_auth_failure: {Pike.Responder.Default, :auth_failed}
```

Create your ETS Table:

```elixir
defmodule YourApp.APIStore do
  use Pike.Store.ETS, table_name: :default_api_keys
end
```

### Using Plug

At its simplest:

```elixir
plug Pike.AuthorizationPlug
```

#### 🔀 Multiple Pipelines

You can define **independent pipelines** for different API key types:

```elixir
pipeline :public_api do
  plug Pike.AuthorizationPlug,
    store: YourApp.APIStore,
    assign_to: :public_api_key
end

pipeline :partner_api do
  plug Pike.AuthorizationPlug,
    store: YourApp.AlternativeAPIStore,
    on_auth_failure: {MyApp.Responder, :auth_failed},
    assign_to: :partner_key
end
```

Then route accordingly:

```elixir
scope "/v1/public", MyAppWeb do
  pipe_through [:api, :public_api]
end

scope "/v1/partner", MyAppWeb do
  pipe_through [:api, :partner_api]
end
```

### Controller Integration

Declare expected permissions using a DSL:

```elixir
defmodule MyAppWeb.ProductController do
  use MyAppWeb, :controller
  use Pike.Authorization, resource: "Products"

  # Uses controller-level resource ("Products")
  @require_permission action: :read
  def index(conn, _params), do: # ...

  # Resource becomes "ProductsMeta"
  @require_permission action: :read, append: "Meta"
  def meta(conn, _params), do: # ...

  # Completely overrides: resource = "VariableProducts"
  @require_permission action: :read, override: "VariableProducts"
  def variations(conn, _params), do: # ...
end
```

---

## Permission Model

Each API key must define a list of permissions:

```elixir
%{
  key: "abc123",
  permissions: [
    %{resource: "Products", scopes: [:read, :write]},
    %{resource: "ProductsMeta", scopes: [:read]},
    %{resource: "VariableProducts", scopes: [:read]}
  ]
}
```

---

## Key Assignment

After successful authentication, the API key is available via:

```elixir
conn.assigns[:pike_api_key]  # or :partner_api_key if overridden
```

This lets you:

* Inspect the key
* Track usage
* Enforce tenant or user-level scoping

---

## Key Management

Pike provides functions for managing API keys:

```elixir
# Create a new key
Pike.insert(%{
  key: "abc123",
  enabled: true,  # Optional, defaults to true
  permissions: [
    %{resource: "Products", scopes: [:read, :write]}
  ]
})

# Enable/disable a key
Pike.disable_key("abc123")
Pike.enable_key("abc123")

# Check if a key is enabled
Pike.key_enabled?("abc123")

# Delete a key
Pike.delete_key("abc123")

# Update a key
Pike.update_key("abc123", %{
  permissions: [
    %{resource: "Products", scopes: [:read]}
  ]
})
```

Disabled keys will return a `:disabled` error reason, which is handled by the responder.

---

## Store Backend

Pike uses a pluggable store interface:

```elixir
@callback get_key(String.t()) :: {:ok, map()} | :error | {:error, :disabled}
@callback action?(map(), resource :: String.t(), action :: atom()) :: boolean()
@callback insert(map()) :: :ok | {:error, term()}  # optional
@callback delete_key(String.t()) :: :ok | {:error, term()}  # optional
@callback update_key(String.t(), map()) :: :ok | {:error, term()}  # optional
```

You can provide your own module and configure it per plug or globally.

---

## 🔖 License

MIT