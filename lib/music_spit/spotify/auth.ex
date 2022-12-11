defmodule MusicSpit.Spotify.Auth do
  @api_url "https://accounts.spotify.com/api/token"
  @finch MusicSpit.Finch.Spotify

  def exchange_code(code) do
    {:ok, %Finch.Response{body: body}} =
      Finch.build(
        :post,
        @api_url,
        headers(),
        URI.encode_query(%{
          code: code,
          redirect_uri: "http://localhost:8081/callback",
          grant_type: "authorization_code"
        })
      )
      |> Finch.request(@finch)

    case Jason.decode(body) do
      {:ok, %{"access_token" => access_token, "refresh_token" => refresh_token, "expires_in" => expires_in}} ->
        {:ok, %{access_token: access_token, refresh_token: refresh_token, expires_in: expires_in}}

      _ ->
        {:error, "bad json"}
    end
  end

  def refresh(token) do
    {:ok, %Finch.Response{body: body}} =
      Finch.build(
        :post,
        @api_url,
        headers(),
        URI.encode_query(%{
          grant_type: "refresh_token",
          refresh_token: token
        })
      )
      |> Finch.request(@finch)

    {:ok, %{"access_token" => access_token}} = Jason.decode(body)

    {:ok, access_token}
  end

  defp headers() do
    [
      {"authorization", "Basic #{get_authorization_header()}"},
      {"content-type", "application/x-www-form-urlencoded"}
    ]
  end

  defp get_authorization_header() do
    config = Application.fetch_env!(:music_spit, MusicSpit.Spotify)
    Base.encode64("#{Keyword.fetch!(config, :client_id)}:#{Keyword.fetch!(config, :client_secret)}")
  end
end
