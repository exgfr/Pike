# Pike

> **Guard at the API Gate** — a lightweight, embeddable Elixir library for API key authentication and fine-grained authorization.

Pike enables API key enforcement with zero external dependencies, pluggable storage backends, resource-aware permissions, and a flexible DSL for defining authorization at the controller and action level.

---

## ✨ Features

* 🔐 Authenticate API keys via Plug
* 🧾 Enforce access control per **resource + action**
* 🧩 Controller DSL for authorization (`@require_permission`)
* 🔁 **Multiple pipelines** with custom key handling
* ⚡️ Fast ETS-backed in-memory store (default)
* 🧩 Pluggable store interface (bring your own backend)
* 🚦 Configurable failure handling per pipeline
* 🧠 Adds authenticated key to `conn.assigns`

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

Global application-wide config (only needed if overriding defaults):

```elixir
config :pike,
  store: Pike.Store.ETS,
  on_auth_failure: {Pike.Responder.Default, :auth_failed}
```

---

## 🔌 Using the Plug

At its simplest:

```elixir
plug Pike.AuthorizationPlug
```

This will:

* Use the ETS store
* Assign the key to `conn.assigns[:pike_api_key]`
* Use the default 401/403/500 failure handler

---

### 🔀 Multiple Pipelines

You can define **independent pipelines** for different API key types:

```elixir
pipeline :public_api do
  plug Pike.AuthorizationPlug,
    store: MyApp.PublicKeyStore,
    assign_to: :public_api_key
end

pipeline :partner_api do
  plug Pike.AuthorizationPlug,
    store: MyApp.PartnerStore,
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

---

## 🧱 Controller Integration

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

## 🔐 Permission Model

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

## 🧾 Key Assignment

After successful authentication, the API key is available via:

```elixir
conn.assigns[:pike_api_key]  # or :partner_api_key if overridden
```

This lets you:

* Inspect the key
* Track usage
* Enforce tenant or user-level scoping

---

## 🧩 Store Backend

Pike uses a pluggable store interface:

```elixir
@callback get_key(String.t()) :: {:ok, map()} | :error
@callback allows?(map(), resource :: String.t(), action :: atom()) :: boolean()
@callback insert(map()) :: :ok | {:error, term()}  # optional
```

You can provide your own module and configure it per plug or globally.

---

### 🚀 Example: ETS Store

```elixir
Pike.Store.ETS.insert(%{
  key: "abc123",
  permissions: [%{resource: "Products", scopes: [:read]}]
})
```

---

## 🚨 Failure Handling

Pike supports configurable auth failure handlers.

### Failure Reason Atoms:

| Reason Atom              | Meaning                                     | HTTP Status |
| ------------------------ | ------------------------------------------- | ----------- |
| `:missing_key`           | No API key provided                         | `401`       |
| `:invalid_format`        | API key is malformed or unparseable         | `400`       |
| `:not_found`             | API key not found                           | `403`       |
| `:disabled`              | API key is disabled                         | `403`       |
| `:expired`               | API key is expired                          | `403`       |
| `:unauthorized_resource` | No access to the resource                   | `403`       |
| `:unauthorized_action`   | Access to resource, but not for this action | `403`       |
| `:store_error`           | Backend store failed                        | `500`       |

### Default:

```elixir
config :pike,
  on_auth_failure: {Pike.Responder.Default, :auth_failed}
```

You can override per pipeline:

```elixir
plug Pike.AuthorizationPlug,
  on_auth_failure: {MyApp.CustomResponder, :auth_failed}
```

---

## 🧠 Customization Summary

| Option            | Default                  | Override At...       |
| ----------------- | ------------------------ | -------------------- |
| `store`           | `Pike.Store.ETS`         | Global or plug-level |
| `assign_to`       | `:pike_api_key`          | Plug-level only      |
| `on_auth_failure` | `Pike.Responder.Default` | Global or plug-level |

---

## 🔖 License

MIT