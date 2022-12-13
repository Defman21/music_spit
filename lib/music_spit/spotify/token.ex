defmodule MusicSpit.Spotify.Token do
  @moduledoc """
  Spotify API Token module.

  Repsponsible for auto-refreshing the access token and store it in an ETS table.
  """
  require Logger
  use GenServer
  alias MusicSpit.Spotify.Auth

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(:ok) do
    ets_table = PersistentEts.new(:spotify_tokens, "spotify_tokens.tab", [:named_table])

    {:ok, %{table: ets_table}}
  end

  def persist_tokens(tokens) do
    GenServer.call(__MODULE__, {:persist_tokens, tokens})
  end

  def retrieve_tokens() do
    GenServer.call(__MODULE__, :retrieve_tokens)
  end

  # Server API

  @impl GenServer
  def handle_call({:persist_tokens, tokens}, _from, state) do
    ets_persist_tokens(state.table, tokens)

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(:retrieve_tokens, _from, state) do
    access_token = lookup(state.table, :access_token)
    refresh_token = lookup(state.table, :refresh_token)
    expires_in = lookup(state.table, :expires_in, 0)
    added_at = lookup(state.table, :added_at, DateTime.from_unix!(0))

    if DateTime.compare(DateTime.now!("Etc/UTC"), DateTime.add(added_at, expires_in, :second)) ==
         :gt and !is_nil(refresh_token) do
      {:ok, access_token} = Auth.refresh(refresh_token)
      Logger.debug("Refreshed access token")

      ets_persist_tokens(
        state.table,
        access_token: access_token,
        refresh_token: refresh_token,
        expires_in: expires_in
      )
    end

    {:reply, %{access_token: access_token, refresh_token: refresh_token}, state}
  end

  # Internal

  defp lookup(table, key, default \\ nil) do
    case :ets.lookup(table, key) do
      [{^key, value}] -> value
      [] -> default
    end
  end

  defp ets_persist_tokens(table, tokens) do
    :ets.insert(table, {:access_token, Keyword.get(tokens, :access_token)})
    :ets.insert(table, {:refresh_token, Keyword.get(tokens, :refresh_token)})
    :ets.insert(table, {:expires_in, Keyword.get(tokens, :expires_in)})
    :ets.insert(table, {:added_at, DateTime.now!("Etc/UTC")})
  end
end
