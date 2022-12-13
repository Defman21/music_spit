defmodule MusicSpit.Odesli do
  @moduledoc """
  Odesli API wrapper.

  Odesli is used to retrieve platform links for a song on another platform.
  """
  use GenServer

  @base_url URI.parse("https://api.song.link/v1-alpha.1/links")
  @finch MusicSpit.Finch.Telegram
  @headers [
    {"content-type", "application/json"}
  ]

  # Client API
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_song(url, opts \\ nil) do
    GenServer.call(__MODULE__, {:get_song, url, opts}, 30_000)
  end

  # Server API

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:get_song, url, opts}, _from, state) do
    {:ok, result} = req(url)

    links =
      case Keyword.get(opts, :platforms) do
        nil ->
          result["linksByPlatform"]

        platforms ->
          Map.filter(result["linksByPlatform"], fn {platform, _} -> platform in platforms end)
      end

    ids = result["entitiesByUniqueId"] |> Enum.map(&build_platform_id/1) |> Enum.into(%{})

    {:reply, %{ids: ids, links: links, human_name: build_human_name(result)}, state}
  end

  # Internal

  defp req(song_url) do
    {:ok, %Finch.Response{body: body}} =
      Finch.build(:get, build_url(song_url), @headers)
      |> Finch.request(@finch)

    {:ok, Jason.decode!(body)}
  end

  defp build_url(song_url) do
    @base_url
    |> Map.put(:query, URI.encode_query(%{url: URI.to_string(song_url)}))
    |> URI.to_string()
  end

  defp build_human_name(%{"entitiesByUniqueId" => entities}) do
    Map.values(entities) |> hd() |> (&"#{&1["artistName"]} - #{&1["title"]}").()
  end

  defp build_platform_id({_, %{"apiProvider" => platform, "id" => id}}), do: {platform, id}
end
