defmodule MusicSpit.Spotify.Web do
  @moduledoc """
  Spotify Callback Web server.

  Handles OAuth2 authorization flow (redirect to Spotify, auth, exchange code for tokens).
  """
  require Logger
  use Plug.Router

  alias MusicSpit.Spotify.{Auth, Api, Token}

  @base_url URI.parse("https://accounts.spotify.com/authorize")

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(:dispatch)

  get "/" do
    config = Application.fetch_env!(:music_spit, MusicSpit.Spotify)

    url =
      @base_url
      |> Map.put(
        :query,
        URI.encode_query(%{
          response_type: "code",
          client_id: Keyword.fetch!(config, :client_id),
          scope: Keyword.fetch!(config, :scopes),
          redirect_uri: Keyword.fetch!(config, :redirect_uri),
          state: UUID.uuid4()
        })
      )

    conn
    |> Plug.Conn.resp(:found, "")
    |> Plug.Conn.put_resp_header("location", URI.to_string(url))
  end

  get "/callback" do
    {:ok, %{access_token: access_token, refresh_token: refresh_token, expires_in: expires_in}} =
      Auth.exchange_code(conn.query_params["code"])

    Token.persist_tokens(
      access_token: access_token,
      refresh_token: refresh_token,
      expires_in: expires_in
    )

    send_resp(conn, 200, Jason.encode!(%{ok: true}))
  end
end
