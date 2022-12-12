defmodule MusicSpit.Spotify.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl Supervisor
  def init(:ok) do
    config = Application.fetch_env!(:music_spit, MusicSpit.Spotify)
    children = [
      {Plug.Cowboy, scheme: :http, plug: MusicSpit.Spotify.Web, options: [port: Keyword.fetch!(config, :port)]},
      MusicSpit.Spotify.Token,
      MusicSpit.Spotify.Api
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
