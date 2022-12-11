defmodule MusicSpit.Updates.Admin do
  use GenServer
  alias MusicSpit.Telegram

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def can_delete_messages?(chat_id) do
    GenServer.call(__MODULE__, {:can_delete_messages, chat_id})
  end

  def can_delete_messages?(chat_id, value) when is_boolean(value) do
    GenServer.cast(__MODULE__, {:can_delete_messages, chat_id, value})
  end

  # Server API

  @impl GenServer
  def init(:ok) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_call({:can_delete_messages, chat_id}, _from, state) do
    case Map.get(state, chat_id) do
      nil ->
        can_delete_messages =
          Telegram.get_chat_administrators(chat_id)
          |> Enum.filter(&(&1["user"]["username"] == "music_spit_bot"))
          |> List.first()
          |> Map.get("can_delete_messages")

        {:reply, can_delete_messages, Map.put(state, chat_id, can_delete_messages)}

      can_delete_messages ->
        {:reply, can_delete_messages, state}
    end
  end

  @impl GenServer
  def handle_cast({:can_delete_messages, chat_id, value}, state) do
    {:noreply, Map.put(state, chat_id, value)}
  end

  # Internal
end
