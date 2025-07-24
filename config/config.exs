import Config

# Default Pike configuration
config :pike,
  # Default store for API keys (defaults to Pike.Store.ETS if not set)
  store: Pike.Store.ETS,

  # Where to assign the API key in conn.assigns (used in AuthorizationPlug)
  assign_to: :pike_api_key,

  # Default failure handler - can be overridden per pipeline
  on_auth_failure: {Pike.Responder.Default, :auth_failed}

# Environment-specific configuration
import_config "#{config_env()}.exs"
