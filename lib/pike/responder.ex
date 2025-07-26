defmodule Pike.Responder do
  @moduledoc """
  Behaviour for handling authorization failures in Pike.

  Implement this module if you want to customize how Pike responds
  when authentication or authorization fails.
  """

  @typedoc "Reasons for authentication or authorization failure"
  @type reason ::
          :missing_key
          | :invalid_format
          | :not_found
          | :disabled
          | :expired
          | :unauthorized_resource
          | :unauthorized_action
          | :store_error

  @callback auth_failed(Plug.Conn.t(), reason) :: Plug.Conn.t()
end
