# Rolling Your Own Pike Store

Pike's extensible architecture allows you to implement custom store backends to suit your specific needs. This guide covers how to create your own store implementation and explores various use cases.

## Store Behavior

To implement a custom store, your module must implement the `Pike.Store` behavior.

### Required Callbacks

```elixir
defmodule MyApp.CustomStore do
  @behaviour Pike.Store
  
  @impl true
  def get_key(key) do
    # Retrieve the key and return either:
    # {:ok, key_data} or :error
    # A third option is {:error, :disabled} for disabled keys
  end
  
  @impl true
  def action?(key_data, resource, action) do
    # Check if the key has permission for the given action on the resource
    # Return boolean
  end
end
```

### Optional Callbacks

```elixir
defmodule MyApp.FullFeaturedStore do
  @behaviour Pike.Store
  
  # Required callbacks from above...
  
  @impl true
  def insert(key_data) do
    # Insert a new key into the store
    # Return :ok or {:error, reason}
  end
  
  @impl true
  def delete_key(key) do
    # Delete a key from the store
    # Return :ok or {:error, reason}
  end
  
  @impl true
  def update_key(key, updates) do
    # Update a key in the store
    # Return :ok or {:error, reason}
  end
end
```

## Common Use Cases

Here are some practical scenarios where a custom store implementation would be valuable:

### 1. Database-Backed Persistence

For production environments, you might want to store API keys in a database:

```elixir
defmodule MyApp.PostgresStore do
  @behaviour Pike.Store
  
  @impl true
  def get_key(key) do
    case Repo.get_by(ApiKey, key: key) do
      nil -> :error
      %{active: false} = api_key -> {:error, :disabled}
      api_key -> {:ok, map_from_schema(api_key)}
    end
  end
  
  @impl true
  def action?(key_data, resource, action) do
    # First check if the key is enabled
    case Map.get(key_data, :enabled, true) do
      false -> false
      true ->
        # Check permissions from the key_data structure
        Enum.any?(key_data.permissions, fn
          %{resource: ^resource, scopes: scopes} when is_list(scopes) -> action in scopes
          _ -> false
        end)
    end
  end
  
  @impl true
  def insert(key_data) do
    %ApiKey{}
    |> ApiKey.changeset(map_to_schema(key_data))
    |> Repo.insert()
    |> case do
      {:ok, _} -> :ok
      error -> error
    end
  end
  
  defp map_from_schema(schema) do
    # Convert database schema to Pike's key format
    # ...
  end
  
  defp map_to_schema(key_data) do
    # Convert Pike's key format to database schema
    # ...
  end
end
```

### 2. Layered Caching Store

Combine database persistence with in-memory caching for optimal performance:

```elixir
defmodule MyApp.CachingStore do
  @behaviour Pike.Store
  
  @impl true
  def get_key(key) do
    case :ets.lookup(:pike_keys_cache, key) do
      [{^key, key_data}] ->
        # Cache hit
        {:ok, key_data}
      [] ->
        # Cache miss - check database
        case MyApp.PostgresStore.get_key(key) do
          {:ok, key_data} = result ->
            # Store in cache for future lookups
            :ets.insert(:pike_keys_cache, {key, key_data})
            result
          error ->
            error
        end
    end
  end
  
  @impl true
  def action?(key_data, resource, action) do
    # First check if the key is enabled
    case Map.get(key_data, :enabled, true) do
      false -> false
      true ->
        # Delegate to core permission check logic for enabled keys
        Enum.any?(key_data.permissions, fn
          %{resource: ^resource, scopes: scopes} when is_list(scopes) -> action in scopes
          _ -> false
        end)
    end
  end
  
  @impl true
  def insert(key_data) do
    with :ok <- MyApp.PostgresStore.insert(key_data) do
      # Also update the cache
      :ets.insert(:pike_keys_cache, {key_data.key, key_data})
      :ok
    end
  end
  
  # Cache initialization
  def init do
    :ets.new(:pike_keys_cache, [:set, :public, :named_table])
    :ok
  end
  
  # Cache invalidation
  def invalidate(key) do
    :ets.delete(:pike_keys_cache, key)
    :ok
  end
  
  # Warm cache from database
  def warm_cache do
    MyApp.Repo.all(MyApp.ApiKey)
    |> Enum.each(fn api_key ->
      key_data = map_from_schema(api_key)
      :ets.insert(:pike_keys_cache, {key_data.key, key_data})
    end)
  end
end
```

### 3. Redis-Backed Store

For distributed systems, Redis provides a shared storage solution:

```elixir
defmodule MyApp.RedisStore do
  @behaviour Pike.Store
  
  @impl true
  def get_key(key) do
    case Redix.command(:redix, ["GET", "pike:keys:#{key}"]) do
      {:ok, nil} -> :error
      {:ok, json} -> 
        {:ok, Jason.decode!(json, keys: :atoms)}
      {:error, _} -> :error
    end
  end
  
  @impl true
  def action?(key_data, resource, action) do
    # First check if the key is enabled
    case Map.get(key_data, :enabled, true) do
      false -> false
      true ->
        # Check permissions from the key_data structure
        Enum.any?(key_data.permissions, fn
          %{resource: ^resource, scopes: scopes} when is_list(scopes) -> action in scopes
          _ -> false
        end)
    end
  end
  
  @impl true
  def insert(key_data) do
    json = Jason.encode!(key_data)
    case Redix.command(:redix, ["SET", "pike:keys:#{key_data.key}", json]) do
      {:ok, "OK"} -> :ok
      error -> {:error, error}
    end
  end
end
```

### 4. Dynamic Rules Store

Add runtime configuration of permission rules:

```elixir
defmodule MyApp.DynamicRulesStore do
  @behaviour Pike.Store
  
  @impl true
  def get_key(key) do
    # Basic key retrieval
    Pike.Store.ETS.get_key(key)
  end
  
  @impl true
  def action?(key_data, resource, action) do
    # First check global rules
    with false <- global_rule_allows?(key_data, resource, action),
         # Then check the key's specific permissions
         false <- Pike.Store.ETS.action?(key_data, resource, action) do
      false
    else
      true -> true
    end
  end
  
  defp global_rule_allows?(key_data, resource, action) do
    # Check for company-wide or role-based rules that
    # might allow this action regardless of specific permissions
    # ...
  end
end
```

### 5. External Auth Service Integration

Delegate authentication to an external service:

```elixir
defmodule MyApp.ExternalAuthStore do
  @behaviour Pike.Store
  
  @impl true
  def get_key(key) do
    case HTTPoison.get("https://auth.example.com/validate", [], headers: [{"Authorization", "Bearer #{key}"}]) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body, keys: :atoms)}
      _error ->
        :error
    end
  end
  
  @impl true
  def action?(key_data, resource, action) do
    # First check if the key is enabled
    case Map.get(key_data, :enabled, true) do
      false -> false
      true ->
        # Check permissions from the key_data structure
        Enum.any?(key_data.permissions, fn
          %{resource: ^resource, scopes: scopes} when is_list(scopes) -> action in scopes
          _ -> false
        end)
    end
  end
end
```

### 6. Multi-Tenant Store

Support different permissions per tenant:

```elixir
defmodule MyApp.MultiTenantStore do
  @behaviour Pike.Store
  
  @impl true
  def get_key(key) do
    case Repo.get_by(ApiKey, key: key) do
      nil -> :error
      api_key -> 
        tenant_id = api_key.tenant_id
        permissions = load_tenant_permissions(tenant_id, api_key.role)
        
        {:ok, %{
          key: api_key.key,
          tenant_id: tenant_id,
          permissions: permissions
        }}
    end
  end
  
  @impl true
  def action?(key_data, resource, action) do
    # Check permissions, scoped to tenant
    # ...
  end
  
  defp load_tenant_permissions(tenant_id, role) do
    # Load the permissions specific to this tenant and role
    # ...
  end
end
```

## Implementation Considerations

When implementing your own store, consider the following aspects:

### Performance

API key validation happens on every request, so optimize for read performance:
- Use in-memory caching for frequently accessed keys
- Minimize network calls and database queries
- Consider background loading/refreshing of keys

### Security

Protect sensitive API key information:
- Encrypt keys at rest if storing in a database
- Use secure channels for communication with external services
- Implement proper error handling to avoid leaking information

### Consistency

For distributed systems:
- Ensure consistent behavior across nodes
- Consider cache invalidation strategies
- Use appropriate locking or versioning for updates

### Testability

Make your store implementation easy to test:
- Allow dependency injection
- Provide a way to mock external dependencies
- Include comprehensive tests for permission logic

## Example: Complete Store Implementation

Here's a complete example of a production-ready store with caching and database persistence:

```elixir
defmodule MyApp.ApiKeyStore do
  @behaviour Pike.Store
  
  use GenServer
  
  # Client API
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl Pike.Store
  def get_key(key) do
    case :ets.lookup(:pike_keys_cache, key) do
      [{^key, key_data}] ->
        {:ok, key_data}
      [] ->
        GenServer.call(__MODULE__, {:db_get_key, key})
    end
  end
  
  @impl Pike.Store
  def action?(key_data, resource, action) do
    Enum.any?(key_data.permissions, fn permission ->
      permission.resource == resource && 
      Enum.member?(permission.scopes, action)
    end)
  end
  
  @impl Pike.Store
  def insert(key_data) do
    GenServer.call(__MODULE__, {:insert, key_data})
  end
  
  # Server callbacks
  
  @impl GenServer
  def init(_opts) do
    :ets.new(:pike_keys_cache, [:set, :public, :named_table])
    
    # Initial load from database
    load_keys_from_database()
    
    # Schedule periodic refresh
    schedule_refresh()
    
    {:ok, %{last_refresh: DateTime.utc_now()}}
  end
  
  @impl GenServer
  def handle_call({:db_get_key, key}, _from, state) do
    result = case MyApp.Repo.get_by(ApiKey, key: key, active: true) do
      nil -> :error
      api_key -> 
        key_data = convert_to_key_data(api_key)
        # Check if the key is disabled
        case Map.get(key_data, :enabled, true) do
          false -> {:error, :disabled}
          true ->
            :ets.insert(:pike_keys_cache, {key, key_data})
            {:ok, key_data}
        end
    end
    
    {:reply, result, state}
  end
  
  @impl GenServer
  def handle_call({:insert, key_data}, _from, state) do
    result = MyApp.Repo.transaction(fn ->
      changeset = ApiKey.changeset(%ApiKey{}, %{
        key: key_data.key,
        permissions: serialize_permissions(key_data.permissions),
        active: true
      })
      
      case MyApp.Repo.insert(changeset) do
        {:ok, _api_key} -> 
          :ets.insert(:pike_keys_cache, {key_data.key, key_data})
          :ok
        {:error, changeset} -> 
          {:error, changeset}
      end
    end)
    
    {:reply, result, state}
  end
  
  @impl GenServer
  def handle_info(:refresh, state) do
    load_keys_from_database()
    schedule_refresh()
    {:noreply, %{state | last_refresh: DateTime.utc_now()}}
  end
  
  # Private functions
  
  defp load_keys_from_database do
    MyApp.Repo.all(ApiKey)
    |> Enum.each(fn api_key ->
      key_data = convert_to_key_data(api_key)
      :ets.insert(:pike_keys_cache, {api_key.key, key_data})
    end)
  end
  
  defp schedule_refresh do
    # Refresh cache every hour
    Process.send_after(self(), :refresh, 60 * 60 * 1000)
  end
  
  defp convert_to_key_data(api_key) do
    %{
      key: api_key.key,
      enabled: api_key.active,
      permissions: deserialize_permissions(api_key.permissions)
    }
  end
  
  defp serialize_permissions(permissions) do
    Jason.encode!(permissions)
  end
  
  defp deserialize_permissions(json) do
    Jason.decode!(json, keys: :atoms)
    |> Enum.map(fn permission ->
      %{
        resource: permission.resource,
        scopes: Enum.map(permission.scopes, &String.to_atom/1)
      }
    end)
  end
end
```

## Conclusion

Rolling your own Pike store provides tremendous flexibility to tailor the authentication and authorization system to your specific needs. Whether you're optimizing for performance, integrating with existing systems, or implementing complex permission rules, a custom store allows you to extend Pike while maintaining its clean API.

Remember to carefully test your store implementation, especially around edge cases in permission checks, as these are critical to your application's security.