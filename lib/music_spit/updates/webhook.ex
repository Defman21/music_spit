defmodule MusicSpit.Updates.Webhook do
  @moduledoc """
  Telegram web-hook server.
  """
  require Logger
  use Plug.Router

  alias MusicSpit.Updates.Handler

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(:dispatch)

  post "/" do
    case Handler.handle(conn.body_params) do
      :ok -> send_resp(conn, 200, "OK")
      _ -> send_resp(conn, 500, "internal server error")
    end
  end
end
