defmodule MusicSpit.Spotify.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl Supervisor
  def init(:ok) do
    children = [
      {Plug.Cowboy, scheme: :http, plug: MusicSpit.Spotify.Web, options: [port: 8081]},
      MusicSpit.Spotify.Token,
      MusicSpit.Spotify.Api
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
