# Understanding Pike Error Responses

This guide explains the common error responses you might encounter when using Pike, why they occur, and how to debug and resolve them.

## Error Response Types

Pike's authorization system produces several types of error responses through its responder interface. Understanding these errors will help you debug authentication and authorization issues in your application.

### Common Error Types

| Error Code | HTTP Status | Description |
|------------|-------------|-------------|
| `:missing_key` | 401 Unauthorized | No Bearer token was provided in the request |
| `:invalid_format` | 400 Bad Request | The provided token format is invalid |
| `:not_found` | 403 Forbidden | The provided token doesn't exist in the store |
| `:disabled` | 403 Forbidden | The token exists but has been disabled |
| `:unauthorized_resource` | 403 Forbidden | The token lacks permission for the requested resource |
| `:unauthorized_action` | 403 Forbidden | The token lacks permission for the specific action |
| `:store_error` | 500 Internal Server Error | An unexpected error occurred in the store

## Debugging Error Responses

### Missing Key (401 Unauthorized)

#### Why This Happens

A `:missing_key` error occurs when:
- The `Authorization` header is completely absent from the request
- The `Authorization` header is present but doesn't use the Bearer scheme
- The `Authorization` header uses Bearer scheme but doesn't include a token

#### Example Response

```
Missing API key
```

#### How to Debug

1. Check if your client is including the `Authorization` header
2. Verify the header format is correct: `Authorization: Bearer your-api-key`
3. Ensure there are no extra spaces or special characters in the header

```elixir
# Inspecting headers in a controller for debugging
def debug_action(conn, _params) do
  IO.inspect(conn.req_headers, label: "Request Headers")
  # Rest of your action...
end
```

### Not Found (403 Forbidden) / Invalid Format (400 Bad Request)

#### Why This Happens

A `:not_found` error occurs when:
- The token doesn't exist in the configured store
- The token has been revoked or deleted
- The token has expired (if using a store with expiration)
- The token format is invalid or corrupted

#### Example Response

```
API key not found
```

#### How to Debug

1. Verify the token exists in your store:

```elixir
# In an IEx console
iex> Pike.get_key("your-api-key")
:error # Token doesn't exist

# Or if using a custom store
iex> MyApp.CustomStore.get_key("your-api-key")
:error # Token doesn't exist
```

2. Check your store implementation for issues:
   - Database connectivity problems
   - Cache inconsistencies
   - Serialization/deserialization errors

3. Enable detailed logging for your store:

```elixir
defmodule MyApp.DebugStore do
  @behaviour Pike.Store
  
  require Logger
  
  @impl true
  def get_key(key) do
    Logger.debug("Fetching key: #{key}")
    
    result = MyApp.RealStore.get_key(key)
    
    case result do
      {:ok, key_data} -> 
        Logger.debug("Found key data: #{inspect(key_data)}")
        result
      :error -> 
        Logger.debug("Key not found: #{key}")
        result
    end
  end
  
  # Implement other callbacks...
end
```

### Unauthorized Action (403 Forbidden)

#### Why This Happens

An `:unauthorized_action` error occurs when:
- The token exists and is valid, but doesn't have the required permissions
- The token's permissions don't include the resource being accessed
- The token's permissions include the resource but not the specific action
- A custom authorization rule rejected the request

#### Example Response

```
Unauthorized action
```

#### How to Debug

1. Check the key's permissions:

```elixir
# In an IEx console
iex> {:ok, key_data} = Pike.get_key("your-api-key")
iex> key_data.permissions
[
  %{resource: "Products", scopes: [:read]},
  %{resource: "Orders", scopes: [:read, :write]}
]
```

2. Verify the required permissions for the action:

```elixir
# In your controller
@require_permission "Products", :write  # This requires :write permission on Products
def update(conn, _params) do
  # ...
end
```

3. Test the permission check directly:

```elixir
iex> {:ok, key_data} = Pike.get_key("your-api-key")
iex> Pike.action?(key_data, "Products", :write)
false  # This indicates lack of permission
```

4. Add debug logging to controller actions:

```elixir
defmodule MyAppWeb.ProductController do
  use MyAppWeb, :controller
  use Pike.Authorization
  
  require Logger
  
  @require_permission "Products", :write
  def update(conn, params) do
    api_key = conn.assigns[:pike_api_key]
    Logger.debug("API Key: #{inspect(api_key)}")
    Logger.debug("Required permission: Products:write")
    
    # Rest of your action...
  end
end
```

### Store Error (500 Internal Server Error)

#### Why This Happens

A `:store_error` occurs when:
- The store implementation raises an exception
- Database connectivity issues
- Memory corruption in ETS-based stores
- Programming errors in custom store implementations

#### Example Response

```
Internal authorization error
```

#### How to Debug

1. Check your application logs for error messages and stack traces
2. Add exception handling to your store implementation:

```elixir
defmodule MyApp.SafeStore do
  @behaviour Pike.Store
  
  require Logger
  
  @impl true
  def get_key(key) do
    try do
      MyApp.RealStore.get_key(key)
    rescue
      e ->
        Logger.error("Error in get_key: #{inspect(e)}")
        Logger.error("Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}")
        :error
    end
  end
  
  # Implement other callbacks with similar exception handling...
end
```

## Custom Error Handling

### Built-in Responders

Pike provides multiple built-in responders:

1. **Default Responder** (`Pike.Responder.Default`):
   - Returns simple plaintext messages with appropriate status codes
   - Provides specific error details for troubleshooting
   - Default option if none is specified

2. **Hardened Responder** (`Pike.Responder.Hardened`):
   - Security-focused responder with minimal information disclosure
   - Uses generic "Access denied" message for all 403 responses
   - Prevents information leakage in production environments
   - Better suited for public-facing APIs

Example usage:
```elixir
# Use the hardened responder for improved security
plug Pike.AuthorizationPlug, on_auth_failure: Pike.Responder.Hardened
```

### Custom Responders

You can customize how Pike responds to errors by implementing the `Pike.Responder` behavior:

```elixir
defmodule MyApp.DetailedResponder do
  @behaviour Pike.Responder
  
  import Plug.Conn
  
  @impl true
  def auth_failed(conn, :missing_key) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{
        error: "Authentication Required",
        details: "Please provide an API key via the Authorization header: Authorization: Bearer your-api-key",
        docs_url: "https://docs.example.com/api/authentication"
    })
    |> halt()
  end
  
  @impl true
  def auth_failed(conn, :not_found) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{
        error: "Invalid API Key",
        details: "The provided API key was not found or is no longer valid",
        docs_url: "https://docs.example.com/api/authentication#valid-keys"
    })
    |> halt()
  end
  
  @impl true
  def auth_failed(conn, :unauthorized_action) do
    # Extract current user info for better error context
    api_key = conn.assigns[:pike_api_key]
    
    # Get the current controller and action
    controller = Phoenix.Controller.controller_module(conn)
    action = Phoenix.Controller.action_name(conn)
    
    # Generate a helpful error message
    conn
    |> put_status(:forbidden)
    |> Phoenix.Controller.json(%{
        error: "Insufficient Permissions",
        details: "Your API key doesn't have the required permissions for this operation",
        key_id: api_key.key,
        resource: controller |> Module.split() |> List.last() |> String.replace("Controller", ""),
        action: action,
        current_permissions: api_key.permissions,
        docs_url: "https://docs.example.com/api/permissions"
    })
    |> halt()
  end
  
  @impl true
  def auth_failed(conn, :store_error) do
    request_id = Logger.metadata()[:request_id] || "unknown"
    
    conn
    |> put_status(:internal_server_error)
    |> Phoenix.Controller.json(%{
        error: "Server Error",
        details: "An unexpected error occurred during authorization",
        request_id: request_id,
        support_contact: "api-support@example.com"
    })
    |> halt()
  end
end
```

Then configure Pike to use your custom responder:

```elixir
# In your router or application config
plug Pike.AuthorizationPlug, on_auth_failure: {MyApp.DetailedResponder, :auth_failed}
```

## Logging and Monitoring

For effective debugging in production, implement comprehensive logging:

### Request Logging Middleware

```elixir
defmodule MyApp.ApiRequestLogger do
  @behaviour Plug
  
  require Logger
  import Plug.Conn
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    start = System.monotonic_time()
    
    # Add request_id to the connection
    request_id = Logger.metadata()[:request_id] || generate_request_id()
    Logger.metadata(request_id: request_id)
    
    conn = put_private(conn, :api_request_start, start)
    
    # Log the request
    Logger.info("API Request: #{conn.method} #{conn.request_path}",
      request_id: request_id,
      remote_ip: format_ip(conn.remote_ip),
      headers: redact_headers(conn.req_headers)
    )
    
    # Register a callback to log after the response
    register_before_send(conn, fn conn ->
      duration = System.monotonic_time() - conn.private[:api_request_start]
      duration_ms = System.convert_time_unit(duration, :native, :millisecond)
      
      log_level = if conn.status >= 400, do: :warn, else: :info
      
      Logger.log(log_level, "API Response: #{conn.status}",
        request_id: request_id,
        duration_ms: duration_ms,
        method: conn.method,
        path: conn.request_path,
        status: conn.status,
        api_key: conn.assigns[:pike_api_key] && conn.assigns[:pike_api_key].key
      )
      
      conn
    end)
  end
  
  defp generate_request_id, do: Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  
  defp format_ip(ip), do: ip |> Tuple.to_list() |> Enum.join(".")
  
  defp redact_headers(headers) do
    Enum.map(headers, fn
      {"authorization", _} -> {"authorization", "[REDACTED]"}
      other -> other
    end)
  end
end
```

Add this plug to your API pipeline:

```elixir
pipeline :api do
  plug :accepts, ["json"]
  plug MyApp.ApiRequestLogger
  plug Pike.AuthorizationPlug
end
```

## Common Issues and Solutions

### Inconsistent Authorization Results

**Symptoms:**
- Authorization works sometimes but fails other times
- Different nodes handle the same request differently

**Possible Causes:**
- Cache inconsistency in distributed environments
- Race conditions in store implementation
- Stale data in caches

**Solutions:**
- Implement proper cache invalidation
- Add versioning to your keys
- Use distributed ETS or a shared cache (Redis)
- Add logging to track key state changes

### Unexpected 401 Errors

**Symptoms:**
- API keys that should be valid return 401 Unauthorized
- Keys work in testing but fail in production

**Possible Causes:**
- Different store implementations between environments
- Key serialization/deserialization issues
- Case sensitivity in key handling
- Whitespace or encoding issues in tokens

**Solutions:**
- Standardize store implementations across environments
- Normalize keys (trim whitespace, handle case consistently)
- Add detailed logging for key lookup failures
- Create a test endpoint that returns key details

### Performance Degradation

**Symptoms:**
- Authorization checks become slow over time
- High latency for API requests

**Possible Causes:**
- Inefficient store implementation
- Database connection pool exhaustion
- Memory leaks in custom stores
- Growing number of keys affecting lookup performance

**Solutions:**
- Optimize store implementation
- Add performance metrics and monitoring
- Implement caching for frequent lookups
- Consider indexing strategies for database-backed stores

## Debugging Checklist

When troubleshooting Pike authorization issues:

1. **Verify the request:**
   - Check that the `Authorization` header is present and correctly formatted
   - Ensure there are no encoding issues with the token

2. **Validate the token:**
   - Confirm the token exists in your store
   - Check that the token hasn't expired or been revoked

3. **Check permissions:**
   - Verify the token has the necessary permissions
   - Ensure the controller is requiring the correct permissions
   - Check for typos in resource names or action atoms

4. **Inspect the environment:**
   - Confirm the correct store is being used
   - Check for environment-specific configuration issues
   - Verify database connectivity for database-backed stores

5. **Review logs:**
   - Look for error messages or exceptions
   - Check for patterns in failed requests
   - Analyze timing data for performance bottlenecks

## Conclusion

Effective debugging of Pike's error responses requires understanding the authorization flow and implementing proper logging and monitoring. By customizing error responses and following the debugging techniques in this guide, you can quickly identify and resolve authorization issues in your application.

Remember that security-related errors should provide enough information for legitimate users to troubleshoot their issues, but not so much that they expose sensitive information or assist potential attackers.