# Pike

> **Guard at the API Gate** — a lightweight, embeddable Elixir library for API key authentication and fine-grained authorization.

Pike enables API key enforcement with zero external dependencies, pluggable storage backends, resource-aware permissions, and a flexible DSL for defining authorization at the controller and action level.

---

## ✨ Features

* 🔐 Validate API keys via Plug
* 🧾 Enforce permissions per **resource + action**
* 🧩 Controller DSL (`@require_permission`) with smart overrides
* ⚡️ Fast ETS-based in-memory backend (default)
* ⚙️ Pluggable store — implement your own with no database required
* 🚦 Configurable failure handling (401, 403, 500… or your own)
* 🧠 Enriches requests with the resolved API key (via `conn.assigns`)

---

## 📦 Installation

Add Pike to your dependencies:

```elixir
def deps do
  [
    {:pike, "~> 0.1.0"}
  ]
end
```

---

## ⚙️ Configuration

```elixir
config :pike,
  store: Pike.Store.ETS, # or your own module implementing Pike.Store
  on_auth_failure: {Pike.Responder.Default, :auth_failed} # optional
```

---

## 🧱 Controller Integration

Use Pike’s authorization DSL to declare resource-level access.

```elixir
defmodule MyAppWeb.ProductController do
  use MyAppWeb, :controller
  use Pike.Authorization, resource: "Products"

  # Uses controller-level resource ("Products")
  @require_permission action: :read
  def index(conn, _params), do: ...

  # Resource becomes "ProductsMeta"
  @require_permission action: :read, append: "Meta"
  def meta(conn, _params), do: ...

  # Completely overrides: resource = "VariableProducts"
  @require_permission action: :read, override: "VariableProducts"
  def variations(conn, _params), do: ...
end
```

---

## 🔌 Plug-Based Authentication

Use `Pike.AuthorizationPlug` in your router or pipeline to enforce authentication.

```elixir
plug Pike.AuthorizationPlug
```

If authentication passes, the API key struct will be added to:

```elixir
conn.assigns[:pike_api_key]
```

This key struct can be inspected in your controller or passed down to your business logic.

---

## 🔐 Permissions Model

Each API key is expected to include a list of permission maps:

```elixir
%{
  key: "abc123",
  permissions: [
    %{resource: "Products", scopes: [:read, :write]},
    %{resource: "Orders/*", scopes: [:read]},
    %{resource: "VariableProducts", scopes: [:read, :delete]}
  ]
}
```

The plug and authorization layer check whether the key includes a permission with a matching `resource` and allowed `action`.

---

## 🧩 Custom Store Backends

By default, Pike ships with an ETS-backed in-memory store. You can replace it by implementing the `Pike.Store` behaviour:

```elixir
defmodule MyApp.PikeStore do
  @behaviour Pike.Store

  def get_key("abc123"), do: {:ok, %{...}}
  def get_key(_), do: :error

  def allows?(key_struct, "Products", :read), do: true
end
```

Then configure your app:

```elixir
config :pike, store: MyApp.PikeStore
```

---

## 🚨 Error Handling

Pike handles authentication failures using a configurable responder.

### Failure Reasons:

| Reason Atom              | Meaning                                         | HTTP Status                 |
| ------------------------ | ----------------------------------------------- | --------------------------- |
| `:missing_key`           | No API key provided                             | `401 Unauthorized`          |
| `:invalid_format`        | API key is malformed or unparseable             | `400 Bad Request`           |
| `:not_found`             | API key not found in the store                  | `403 Forbidden`             |
| `:disabled`              | API key is present but explicitly disabled      | `403 Forbidden`             |
| `:expired`               | API key exists but has expired                  | `403 Forbidden`             |
| `:unauthorized_resource` | Key lacks permission for the requested resource | `403 Forbidden`             |
| `:unauthorized_action`   | Key has resource access, but not the action     | `403 Forbidden`             |
| `:store_error`           | Backend store failed or could not respond       | `500 Internal Server Error` |



### Default Response

```elixir
Pike.Responder.Default
```

Returns appropriate HTTP error codes (401, 403, 500). You can override this:

```elixir
config :pike, on_auth_failure: {MyApp.CustomResponder, :auth_failed}
```

---

## 💡 Planned (Future Versions)

* TTL or expiration checking per key
* IP/domain allowlisting
* LiveView dashboard (admin view)
* HMAC/JWT signed key support
* Rate limiting via token bucket (e.g. `ExRated`)

---

## 🧪 Example Test Key (ETS)

```elixir
Pike.Store.ETS.insert(%{
  key: "abc123",
  permissions: [
    %{resource: "Products", scopes: [:read]}
  ]
})
```

---

## 🔖 License

MIT