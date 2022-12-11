defmodule MusicSpit.Updates.Polling do
  require Logger
  use GenServer
  alias MusicSpit.Telegram
  alias MusicSpit.Updates.Handler

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def poll() do
    GenServer.cast(__MODULE__, :start_polling)
  end

  # Server API

  @impl GenServer
  @spec init(keyword) :: {:ok, %{period: non_neg_integer}}
  def init(opts) do
    poll_period = opts |> Keyword.get(:polling_period, 3000)
    Process.send_after(self(), {:poll, nil}, poll_period)
    {:ok, %{period: poll_period}}
  end

  @impl GenServer
  def handle_cast(:start_polling, state) do
    send(self(), {:poll, nil})
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:poll, offset}, state) do
    updates = Telegram.get_updates(offset, 100)

    updates
    |> Enum.each(&Handler.handle/1)

    updates
    |> List.last()
    |> (fn update ->
          offset = if update, do: update["update_id"] + 1, else: offset
          Process.send_after(self(), {:poll, offset}, state.period)
        end).()

    {:noreply, state}
  end
end
