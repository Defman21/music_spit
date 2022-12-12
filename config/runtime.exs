import Config

config :music_spit, MusicSpit.Telegram,
  token: System.fetch_env!("TELEGRAM_TOKEN"),
  allowed_chats:
    System.fetch_env!("TELEGRAM_CHAT_IDS")
    |> String.split(" ")
    |> Enum.into(%{}, &{String.to_integer(&1), nil})

config :music_spit, MusicSpit.Spotify,
  playlist_id: System.fetch_env!("SPOTIFY_PLAYLIST_ID"),
  client_id: System.fetch_env!("SPOTIFY_CLIENT_ID"),
  client_secret: System.fetch_env!("SPOTIFY_CLIENT_SECRET"),
  redirect_uri: System.fetch_env!("SPOTIFY_REDIRECT_URI"),
  scopes:
    System.get_env(
      "SPOTIFY_SCOPES",
      "user-read-private user-read-email playlist-read-private playlist-modify-private"
    ),
  port: System.get_env("SPOTIFY_PORT", "8081") |> String.to_integer()

config :music_spit, MusicSpit.Updates,
  mode: System.fetch_env!("TELEGRAM_UPDATES_MODE") |> String.to_atom(),
  polling_period:
    System.get_env("TELEGRAM_UPDATES_POLLING_PERIOD", "3000") |> String.to_integer(),
  # todo: not implemented yet
  webhook_url: System.get_env("TELEGRAM_UPDATES_WEBHOOK_URL", nil)
