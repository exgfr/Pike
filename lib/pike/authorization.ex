defmodule Pike.Authorization do
  @moduledoc """
  DSL for declaring authorization requirements in Phoenix controllers.

  ## Usage

      use Pike.Authorization, resource: "Products"

      @require_permission action: :read
      def index(conn, _params), do: ...

      @require_permission action: :read, append: "Meta"
      def meta(conn, _params), do: ...

      @require_permission action: :read, override: "VariableProducts"
      def custom(conn, _params), do: ...
  """

  defmacro __using__(opts) do
    resource = Keyword.fetch!(opts, :resource)

    quote do
      @before_compile Pike.Authorization
      @pike_default_resource unquote(resource)
      Module.register_attribute(__MODULE__, :pike_permissions, accumulate: true)

      import Pike.Authorization, only: [require_permission: 1]
      plug(:authorize_api_key)
    end
  end

  defmacro require_permission opts do
    action = __CALLER__.function |> elem(0)

    quote do
      @pike_permissions {unquote(action), unquote(opts)}
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def authorize_api_key(conn, _opts) do
        action = Phoenix.Controller.action_name(conn)
        key = conn.assigns[:pike_api_key] || conn.assigns[:api_key] || nil

        default_resource = Module.get_attribute(__MODULE__, :pike_default_resource)
        permissions = Module.get_attribute(__MODULE__, :pike_permissions)

        case Enum.find(permissions, fn {a, _} -> a == action end) do
          {_action, opts} ->
            resource =
              cond do
                Keyword.has_key?(opts, :override) -> opts[:override]
                Keyword.has_key?(opts, :append) -> default_resource <> opts[:append]
                true -> default_resource
              end

            action = opts[:action]

            if Pike.action?(key, resource: resource, action: action) do
              conn
            else
              {mod, fun} =
                Application.get_env(
                  :pike,
                  :on_auth_failure,
                  {Pike.Responder.Default, :auth_failed}
                )

              apply(mod, fun, [conn, :unauthorized_action])
            end

          nil ->
            # No permission required for this action
            conn
        end
      end
    end
  end
end
