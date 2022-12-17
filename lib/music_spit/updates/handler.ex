defmodule MusicSpit.Updates.Handler do
  @moduledoc """
  Telegram updates handler.
  """
  require Logger
  alias MusicSpit.Updates.Admin
  alias MusicSpit.Odesli
  alias MusicSpit.Telegram
  alias MusicSpit.Spotify.Api

  @platforms ["appleMusic", "spotify"]
  @human_names %{"appleMusic" => "Apple Music", "spotify" => "Spotify"}

  def handle(%{"message" => %{"chat" => %{"id" => chat_id}}} = update) do
    case allowed_update?(chat_id) do
      true -> handle_allowed(update)
      false -> handle_disallowed(update)
    end
  end

  def handle(%{"callback_query" => %{"message" => %{"chat" => %{"id" => chat_id}}}} = update) do
    case allowed_update?(chat_id) do
      true -> handle_allowed(update)
      false -> handle_disallowed(update)
    end
  end

  def handle(%{"my_chat_member" => %{"chat" => %{"id" => chat_id}}} = update) do
    case allowed_update?(chat_id) do
      true -> handle_allowed(update)
      false -> handle_disallowed(update)
    end
  end

  def handle(update), do: handle_disallowed(update)

  defp allowed_update?(chat_id),
    do:
      Application.fetch_env!(:music_spit, MusicSpit.Telegram)
      |> Keyword.fetch!(:allowed_chats)
      |> Map.has_key?(chat_id)

  defp handle_allowed(%{"message" => %{"entities" => entities}} = message)
       when length(entities) > 0 do
    Enum.filter(entities, &(&1["type"] == "url")) |> List.first() |> handle_entity(message)
  end

  defp handle_allowed(%{
         "callback_query" => %{
           "id" => id,
           "message" => message,
           "data" => data
         }
       }) do
    handle_callback(id, data, message)
    :ok
  end

  defp handle_allowed(%{
         "my_chat_member" => %{
           "chat" => %{"id" => chat_id},
           "new_chat_member" => %{"can_delete_messages" => can_delete_messages}
         }
       }) do
    Admin.can_delete_messages?(chat_id, can_delete_messages)
    Logger.debug("Changed can_delete_messages for chat #{chat_id} to #{can_delete_messages}")
    :ok
  end

  defp handle_allowed(_), do: :ok

  defp handle_disallowed(update) do
    Logger.debug(update)
    :ok
  end

  defp handle_entity(nil, _), do: :ok

  defp handle_entity(entity, %{
         "message" => %{
           "message_id" => message_id,
           "chat" => %{"id" => chat_id},
           "text" => text
         }
       }) do
    case String.slice(text, entity["offset"], entity["length"])
         |> URI.parse()
         |> validate_url()
         |> send_message(chat_id) do
      :ok ->
        if Admin.can_delete_messages?(chat_id),
          do: Telegram.delete_message(chat_id, message_id)

      :skip ->
        Logger.debug("Skipped update")
    end

    :ok
  end

  defp handle_callback(id, "rofl", _message) do
    Telegram.answer_callback_query(id, text: "По ебалу себе кликни, умник")
  end

  defp handle_callback(id, "approve:" <> spotify_id, message) do
    Api.add_track_to_playlist(
      spotify_id,
      Application.fetch_env!(:music_spit, MusicSpit.Spotify) |> Keyword.fetch!(:playlist_id)
    )

    Telegram.answer_callback_query(id)

    Telegram.edit_message_reply_markup(message["message_id"], message["chat"]["id"],
      reply_markup: %{
        inline_keyboard: [
          [
            %{callback_data: "rofl", text: "Добавлено! ❤️"},
            %{callback_data: "approve:#{spotify_id}", text: "Добавить 😵‍💫"}
          ]
        ]
      }
    )
  end

  defp handle_callback(id, "reject:" <> spotify_id, message) do
    Telegram.answer_callback_query(id)

    Telegram.edit_message_reply_markup(message["message_id"], message["chat"]["id"],
      reply_markup: %{
        inline_keyboard: [
          [
            %{callback_data: "rofl", text: "Не добавлено 😢"},
            %{callback_data: "approve:#{spotify_id}", text: "Добавить 😵‍💫"}
          ]
        ]
      }
    )
  end

  defp validate_url(%{host: "open.spotify.com", path: "/track/" <> _} = url), do: url
  defp validate_url(%{host: "geo.music.apple.com"} = url), do: url
  defp validate_url(%{host: "music.apple.com"} = url), do: url
  defp validate_url(%{host: "itunes.apple.com"} = url), do: url
  defp validate_url(%{host: "music.yandex.com"} = url), do: url
  defp validate_url(%{host: "music.yandex.ru"} = url), do: url
  defp validate_url(_), do: :invalid_url

  defp send_message(:invalid_url, _), do: :skip

  defp send_message(url, chat_id) do
    %{"message_id" => message_id} = Telegram.send_message_blocked(chat_id, "Ищем песенку")

    case Odesli.get_song(url, platforms: @platforms) |> get_song_message_text() do
      {:ok, text, markup} ->
        Telegram.edit_message(message_id, chat_id,
          text: text,
          reply_markup: markup,
          parse_mode: "MarkdownV2"
        )

      {:not_found, text, nil} ->
        Telegram.edit_message(message_id, chat_id, text: text, parse_mode: "MarkdownV2")
    end

    :ok
  end

  defp get_song_message_text(%{ids: %{"spotify" => id}, links: song_links, human_name: human_name}) do
    markup = %{
      inline_keyboard: [
        [
          %{callback_data: "approve:#{id}", text: "✅"},
          %{callback_data: "reject:#{id}", text: "❌"}
        ]
      ]
    }

    message =
      [
        Telegram.escape(human_name),
        "",
        Enum.map_join(song_links, " \\| ", &build_human_url/1)
      ]
      |> Enum.join("\n")

    {:ok, message, markup}
  end

  defp get_song_message_text(%{ids: %{}, links: %{}, human_name: human_name}) do
    {:not_found, "Песня `#{Telegram.escape(human_name)}` не найдена в Spotify 😢", nil}
  end

  defp build_human_url({platform, song}), do: "[#{@human_names[platform]}](#{song["url"]})"
end
