defmodule MusicSpit.Spotify.Api do
  @moduledoc """
  Spotify API wrapper
  """
  use GenServer
  @base_url URI.parse("https://api.spotify.com/v1/playlists")
  @finch MusicSpit.Finch.Spotify

  alias MusicSpit.Spotify.Token

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def get_playlist(playlist_id) do
    GenServer.call(__MODULE__, {:get_playlist, playlist_id})
  end

  def add_track_to_playlist(track_id, playlist_id) do
    GenServer.call(__MODULE__, {:add_track_to_playlist, track_id, playlist_id})
  end

  @impl GenServer
  def init(:ok) do
    {:ok, nil}
  end

  @impl GenServer
  def handle_call({:add_track_to_playlist, track_id, playlist_id}, _from, _state) do
    %{access_token: access_token} = Token.retrieve_tokens()

    {:ok, %Finch.Response{body: body}} =
      Finch.build(
        :post,
        method_url("playlists/#{playlist_id}/tracks"),
        [
          {"authorization", "Bearer #{access_token}"},
          {"content-type", "application/json"}
        ],
        Jason.encode!(%{
          uris: [
            "spotify:track:#{track_id}"
          ]
        })
      )
      |> Finch.request(@finch)

    case Jason.decode!(body) do
      %{"snapshot_id" => _} -> {:reply, :ok, nil}
      json -> {:reply, {:error, json}, nil}
    end
  end

  @impl GenServer
  def handle_call({:get_playlist, playlist_id}, _from, _state) do
    %{access_token: access_token} = Token.retrieve_tokens()

    {:ok, %Finch.Response{body: body}} =
      Finch.build(
        :get,
        method_url("playlists/#{playlist_id}"),
        [
          {"authorization", "Bearer #{access_token}"}
        ],
        nil
      )
      |> Finch.request(@finch)

    {:reply, Jason.decode!(body), nil}
  end

  defp method_url(method) do
    URI.merge(@base_url, method) |> to_string()
  end
end
