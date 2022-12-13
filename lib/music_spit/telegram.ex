defmodule MusicSpit.Telegram do
  @moduledoc """
  Telegram API wrapper.
  """
  require Logger
  use GenServer

  @base_url "https://api.telegram.org/"
  @finch MusicSpit.Finch.Telegram
  @headers [
    {"content-type", "application/json"}
  ]
  @escape_chars ~r/([_*\[\]\(\)~`>#+-=\|\{\}\.\!])/

  # Client API
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_me do
    GenServer.call(__MODULE__, :get_me)
  end

  def get_updates(offset \\ nil, limit \\ nil, opts \\ []) do
    GenServer.call(__MODULE__, {:get_updates, offset, limit, opts})
  end

  def send_message(chat_id, text, opts \\ []) do
    GenServer.cast(__MODULE__, {:send_message, chat_id, text, opts})
  end

  def send_message_blocked(chat_id, text, opts \\ []) do
    GenServer.call(__MODULE__, {:send_message, chat_id, text, opts})
  end

  def edit_message(message_id, chat_id, opts \\ []) do
    GenServer.cast(__MODULE__, {:edit_message, message_id, chat_id, opts})
  end

  def edit_message_reply_markup(message_id, chat_id, opts \\ []) do
    GenServer.cast(__MODULE__, {:edit_message_reply_markup, message_id, chat_id, opts})
  end

  def set_webhook(url, opts \\ []) do
    GenServer.cast(__MODULE__, {:set_webhook, url, opts})
  end

  def delete_webhook do
    GenServer.cast(__MODULE__, :delete_webhook)
  end

  def get_chat_administrators(chat_id) do
    GenServer.call(__MODULE__, {:get_chat_administrators, chat_id})
  end

  def answer_callback_query(callback_query_id, opts \\ []) do
    GenServer.cast(__MODULE__, {:answer_callback_query, callback_query_id, opts})
  end

  def delete_message(chat_id, message_id) do
    GenServer.cast(__MODULE__, {:delete_message, chat_id, message_id})
  end

  def escape(text), do: String.replace(text, @escape_chars, &"\\#{&1}")

  # Server API

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_me, _from, state) do
    {:ok, result} = req("getMe")

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:get_updates, offset, limit, opts}, _from, state) do
    {:ok, result} = req("getUpdates", merge(opts, offset: offset, limit: limit))

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:get_chat_administrators, chat_id}, _from, state) do
    case req("getChatAdministrators", %{chat_id: chat_id}) do
      {:ok, result} ->
        {:reply, result, state}

      {:error, "Bad Request: there are no administrators in the private chat"} ->
        {:reply, [%{"status" => "creator"}], state}
    end
  end

  @impl GenServer
  def handle_call({:send_message, chat_id, text, opts}, _from, state) do
    {:ok, message} = req("sendMessage", merge(opts, chat_id: chat_id, text: text))

    {:reply, message, state}
  end

  @impl GenServer
  def handle_cast({:send_message, chat_id, text, opts}, state) do
    {:ok, _} = req("sendMessage", merge(opts, chat_id: chat_id, text: text))

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:set_webhook, url, opts}, state) do
    {:ok, _} = req("setWebhook", merge(opts, url: url))

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:delete_webhook, state) do
    {:ok, _} = req("deleteWebhook")

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:answer_callback_query, callback_query_id, opts}, state) do
    {:ok, _} = req("answerCallbackQuery", merge(opts, callback_query_id: callback_query_id))

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:edit_message, message_id, chat_id, opts}, state) do
    {:ok, _} = req("editMessageText", merge(opts, message_id: message_id, chat_id: chat_id))

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:edit_message_reply_markup, message_id, chat_id, opts}, state) do
    case req("editMessageReplyMarkup", merge(opts, message_id: message_id, chat_id: chat_id)) do
      {:ok, _} -> nil
      {:error, error} -> Logger.error("Failed to update message reply markup: #{error}")
    end

    {:noreply, state}
  end

  def handle_cast({:delete_message, chat_id, message_id}, state) do
    {:ok, _} = req("deleteMessage", %{chat_id: chat_id, message_id: message_id})

    {:noreply, state}
  end

  # Internal

  defp req(name, body \\ nil) do
    {:ok, %Finch.Response{body: body}} =
      Finch.build(:post, method(name), @headers, Jason.encode!(body))
      |> Finch.request(@finch)

    case Jason.decode!(body) do
      %{"ok" => true, "result" => result} -> {:ok, result}
      %{"ok" => false, "description" => error} -> {:error, error}
    end
  end

  defp bot_url do
    token =
      Application.fetch_env!(:music_spit, MusicSpit.Telegram)
      |> Keyword.fetch!(:token)

    URI.merge(@base_url, "/bot#{token}/") |> to_string()
  end

  defp method(name) do
    URI.merge(bot_url(), name) |> to_string()
  end

  defp merge(opts, new_opts) do
    Keyword.merge(opts, new_opts) |> Enum.into(%{})
  end
end
