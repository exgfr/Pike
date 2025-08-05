defmodule Pike.Authorization2 do
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
      @pike_default_resource unquote(resource)

      @before_compile Pike.Authorization2 # Trigger compilation phase

      Module.register_attribute(__MODULE__, :require_permission, persist: false)
      Module.register_attribute(__MODULE__, :__permissions__, accumulate: true)

      @on_definition Pike.Authorization2 # Hook into function definitions

      plug(:authorize_api_key)
    end
  end

  # This is called every time a function is defined
  def __on_definition__(env, _kind, name, args, _guards, _body) do
    arity = length(args)
    example = Module.get_attribute(env.module, :require_permission)

    if is_list(example) do
      Module.put_attribute(env.module, :__permissions__, {{name, arity}, example})
    end

    Module.delete_attribute(env.module, :require_permission)
  end

  defmacro __before_compile__(env) do
    default_resource = Module.get_attribute(env.module, :pike_default_resource)

    permissions =
      Module.get_attribute(env.module, :__permissions__)
      |> Enum.into(%{})

    quote do
      def authorize_api_key(conn, _opts) do
        action = Phoenix.Controller.action_name(conn)
        key = conn.assigns[:pike_api_key] || conn.assigns[:api_key] || nil
        permissions = __MODULE__.__permissions__()

        Pike.Authorization2.handle_request(conn, action, key, permissions, @pike_default_resource)
      end

      def __permissions__, do: unquote(Macro.escape(permissions))
    end
  end

  def handle_request(conn, action, key, permission, pike_default_resource) do
    case find_permission(action, permissions) do
      nil ->
        {mod, fun} =
          Application.get_env(
            :pike,
            :on_auth_failure,
            {Pike.Responder.Default, :auth_failed}
          )

        apply(mod, fun, [conn, :unauthorized_action])

      {{_action, _arity}, opts} ->
        resource = get_resource(opts, pike_default_resource)

        authorize_action(conn, key, resource, action)
    end
  end

  defp authorize_action(conn, key, resource, action) do
    if Pike.action?(key, [resource: resource, action: action]) do
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
  end

  defp find_permission(action, permissions) do
    Enum.find(permissions, fn {{a, _}, _} -> a == action end)
  end

  defp get_resource(opts, default_resource) do
    cond do
      Keyword.has_key?(opts, :override) -> opts[:override]
      Keyword.has_key?(opts, :append) -> default_resource <> opts[:append]
      true -> default_resource
    end
  end

end
