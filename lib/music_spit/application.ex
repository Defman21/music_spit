defmodule MusicSpit.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: MusicSpit.Finch.Telegram},
      {Finch, name: MusicSpit.Finch.Odelsi},
      {Finch, name: MusicSpit.Finch.Spotify},
      MusicSpit.Telegram,
      MusicSpit.Odelsi,
      MusicSpit.Updates.Supervisor,
      MusicSpit.Spotify.Supervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MusicSpit.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
