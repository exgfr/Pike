# Pike Quick Start Guide

Pike is a lightweight Elixir library for API key authentication and fine-grained authorization.

## Installation

Add Pike to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pike, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Basic Setup

### 1. Configure Pike

Create a configuration in your `config.exs`:

```elixir
config :pike,
  store: Pike.Store.ETS
```

### 2. Create your ETS Table Module

```elixir
defmodule YourApp.APIStore do
  use Pike.Store.ETS, table_name: :default_api_keys
end
```

### 3. Add the Authentication Plug to Your Pipeline

```elixir
# In your router or pipeline
pipeline :api do
  plug :accepts, ["json"]
  plug Pike.AuthorizationPlug
end
```

## Basic Usage

### Creating and Managing API Keys

```elixir
# Create an API key with permissions
api_key = %{
  key: "abc123",
  permissions: [
    %{resource: "Products", scopes: [:read, :write]},
    %{resource: "Orders", scopes: [:read]}
  ]
}

# Insert the key
Pike.insert(api_key)
```

### Requiring Permissions in Controllers

```elixir
defmodule MyApp.ProductController do
  use MyApp.Web, :controller
  use Pike.Authorization
  
  @require_permission "Products:read"
  def index(conn, _params) do
    # Only accessible with Products:read permission
    # ...
  end
  
  @require_permission "Products:write"
  def create(conn, _params) do
    # Only accessible with Products:write permission
    # ...
  end
end
```

### Checking Permissions Programmatically

```elixir
# Get an API key
api_key = Pike.get_key("abc123")

# Check if the key allows a specific action
if Pike.action?(api_key, "Products", :read) do
  # Perform the operation
end
```

## Next Steps

For more advanced configuration and usage, see the full [documentation](https://hexdocs.pm/pike).