defmodule MusicSpit.Updates.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl Supervisor
  def init(:ok) do
    config = Application.fetch_env!(:music_spit, MusicSpit.Updates)

    updates_child =
      case Keyword.fetch!(config, :mode) do
        :long_polling ->
          {MusicSpit.Updates.Polling, config}

        :webhook ->
          {Plug.Cowboy,
           scheme: :http,
           plug: MusicSpit.Updates.Webhook,
           options: [port: Keyword.fetch!(config, :port)]}
      end

    children = [
      updates_child,
      MusicSpit.Updates.Admin
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
