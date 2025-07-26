# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Pike is a lightweight, embeddable Elixir library for API key authentication and fine-grained authorization. It provides a plug-compatible middleware system and a resource-based DSL for defining authorization rules at the controller and action level.

Key features:
- API key authentication via Plug
- Resource + action-based permissions system
- Controller DSL for authorization (`@require_permission`)
- Support for multiple pipelines with independent configs
- Default ETS-backed in-memory store
- Pluggable store interface for custom backends
- Configurable failure handling

## Development Commands

### Basic Elixir Commands

```bash
# Compile the project
mix compile

# Run all tests
mix test

# Run a specific test file
mix test test/path/to/test_file.exs

# Generate documentation
mix docs

# Format code
mix format

# Start an interactive Elixir shell with the project loaded
iex -S mix
```

### Common Development Tasks

```bash
# Install dependencies
mix deps.get

# Check for compiler warnings
mix compile --warnings-as-errors

# Check for code formatting issues
mix format --check-formatted

# Create a new release
mix hex.build
```

## Code Architecture

Pike follows a modular architecture with these key components:

1. **Public API** (`pike.ex`):
   - Provides developer-facing helpers like `get_key/1` and `action?/2`
   - Delegates to the configured store
   - Handles configuration resolution

2. **Authorization Plug** (`pike/authorization_plug.ex`):
   - Authenticates API requests by checking for Bearer tokens
   - Verifies keys against the configured store
   - Assigns valid keys to `conn.assigns`
   - Delegates failure handling to a configured responder

3. **Authorization DSL** (`pike/authorization.ex`):
   - Implements the `@require_permission` macro
   - Allows defining permissions at the controller/action level
   - Supports resource name overrides and appends
   - Injects a `plug :authorize_api_key` into the controller

4. **Store Interface** (`pike/store.ex`):
   - Defines the behavior for key storage backends
   - Requires `get_key/1`, `action?/3`, and optional `insert/1`

5. **Default ETS Store** (`pike/store/ets.ex`):
   - Default in-memory implementation using ETS
   - No external dependencies required
   - Handles key lookup and permission checks

6. **Responder Interface** (`pike/responder.ex`):
   - Defines the interface for auth failure handlers
   - Maps reason atoms to appropriate HTTP responses

7. **Default Responder** (`pike/responder/default.ex`):
   - Standard implementation returning 401/403/500 status codes based on failure type

## Key Concepts

### API Key Format

API keys are structured as maps with permissions:

```elixir
%{
  key: "abc123",
  permissions: [
    %{resource: "Products", scopes: [:read, :write]},
    %{resource: "ProductsMeta", scopes: [:read]}
  ]
}
```

### Permission Model

Permissions are defined per resource and action (scope):
- Resources are string identifiers (e.g., "Products")
- Actions/scopes are atoms (e.g., `:read`, `:write`)

### Authorization Flow

1. The `AuthorizationPlug` extracts the Bearer token from the request header
2. The configured store validates the key and checks permissions
3. Valid keys are assigned to `conn.assigns[:pike_api_key]` (or custom assign)
4. The controller's action permission requirements are checked via DSL
5. Unauthorized requests are handled by the configured responder

### Customization Options

Pike can be customized at both the global and per-pipeline level:
- `store`: The storage backend (default: `Pike.Store.ETS`)
- `assign_to`: Where to assign the key (default: `:pike_api_key`)
- `on_auth_failure`: Failure handler (default: `Pike.Responder.Default`)