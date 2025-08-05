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
      @pike_default_resource unquote(resource)

      @before_compile Pike.Authorization # Trigger compilation phase

      Module.register_attribute(__MODULE__, :require_permission, persist: false)
      Module.register_attribute(__MODULE__, :__permissions__, accumulate: true)

      @on_definition Pike.Authorization # Hook into function definitions

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
      Module.get_attribute(env.module, :__permissions__) || []
      |> Enum.into(%{})

    quote do
      def authorize_api_key(conn, _opts) do
        action = Phoenix.Controller.action_name(conn)
        key = conn.assigns[:pike_api_key] || conn.assigns[:api_key] || nil
        permissions = __MODULE__.__permissions__()

        IO.inspect("Authorizing action: #{action}", label: "Pike.Authorization")
        IO.inspect(permissions, label: "Pike.Authorization:permissions")

        Pike.Authorization.handle_request(conn, action, key, permissions, @pike_default_resource)
      end

      def __permissions__, do: unquote(Macro.escape(permissions))
    end
  end

  def handle_request(conn, action, key, permissions, pike_default_resource) do
    # Ensure action is an atom for lookup
    action_atom = if is_binary(action), do: String.to_atom(action), else: action

    IO.inspect("Checking permission for action: #{inspect(action_atom)}", label: "Pike.Authorization")

    case find_permission(action_atom, permissions) do
      nil ->
        # No permission required for this action
        IO.inspect("No permission required for action: #{inspect(action_atom)}", label: "Pike.Authorization")
        conn

      {{_action, _arity}, opts} ->
        IO.inspect("Found permission requirements: #{inspect(opts)}", label: "Pike.Authorization")
        resource = get_resource(opts, pike_default_resource)
        action_permission = opts[:action]

        authorize_action(conn, key, resource, action_permission)
    end
  end

  defp authorize_action(conn, key, resource, action) do
    IO.inspect("Checking permission for resource: #{resource}, action: #{action}", label: "Pike.Authorization")

    if Pike.action?(key, [resource: resource, action: action]) do
      IO.inspect("Permission granted", label: "Pike.Authorization")
      conn
    else
      IO.inspect("Permission denied", label: "Pike.Authorization")
      {mod, fun} =
        Application.get_env(
          :pike,
          :on_auth_failure,
          {Pike.Responder.Default, :auth_failed}
        )

      apply(mod, fun, [conn, :unauthorized_action])
    end
  end

  # Handle both string and atom action names
  defp find_permission(action, permissions) when is_binary(action) do
    find_permission(String.to_atom(action), permissions)
  end

  defp find_permission(action, permissions) when is_atom(action) do
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
