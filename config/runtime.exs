import Config

# Runtime configuration is executed during application startup
# Useful for environment variables and other runtime settings
if config_env() == :prod do
  config :pike, []
  # Add any production-specific runtime configuration here
end
