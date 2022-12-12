defmodule MusicSpit.Updates.Handler do
  require Logger
  alias MusicSpit.Updates.Admin
  alias MusicSpit.Odelsi
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

  defp handle_allowed(%{
         "message" => %{
           "message_id" => message_id,
           "chat" => %{"id" => chat_id} = chat,
           "from" => from,
           "text" => text,
           "entities" => entities
         }
       })
       when length(entities) > 0 do
    Logger.debug("#{from["username"]}: #{text}")

    case Enum.filter(entities, &(&1["type"] == "url")) |> List.first() do
      nil ->
        :ok

      entity ->
        with :ok <-
               String.slice(text, entity["offset"], entity["length"])
               |> URI.parse()
               |> handle_url()
               |> send_message(chat["id"]),
             true <- Admin.can_delete_messages?(chat_id) do
          Telegram.delete_message(chat_id, message_id)
        else
          :skip -> Logger.debug("Skipped update")
        end

        :ok
    end
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

  defp handle_url(%{host: "open.spotify.com", path: "/track/" <> _} = url) do
    Odelsi.get_song(url, platforms: @platforms)
  end

  defp handle_url(%{host: "geo.music.apple.com"} = url) do
    Odelsi.get_song(url, platforms: @platforms)
  end

  defp handle_url(%{host: "music.apple.com"} = url) do
    Odelsi.get_song(url, platforms: @platforms)
  end

  defp handle_url(%{host: "itunes.apple.com"} = url) do
    Odelsi.get_song(url, platforms: @platforms)
  end

  defp handle_url(_), do: nil

  defp send_message(
         %{ids: %{"spotify" => id}, links: song_links, human_name: human_name},
         chat_id
       ) do
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
        Enum.map(song_links, &build_human_url/1) |> Enum.join(" \\| ")
      ]
      |> Enum.join("\n")

    Telegram.send_message(chat_id, message, parse_mode: "MarkdownV2", reply_markup: markup)

    :ok
  end

  defp send_message(%{ids: %{}, links: %{}, human_name: human_name}, chat_id) do
    Telegram.send_message(
      chat_id,
      "Песня `#{Telegram.escape(human_name)}` не найдена в Spotify 😢",
      parse_mode: "MarkdownV2"
    )

    :ok
  end

  defp send_message(nil, _), do: :skip

  defp build_human_url({platform, song}), do: "[#{@human_names[platform]}](#{song["url"]})"
end
