defmodule Timesup.Game do
  require Logger
  use GenServer
  alias Ecto.Multi
  alias Timesup.GameState
  alias Timesup.Repo
  alias Timesup.StoredGame

  # Client

  def start_link(options) do
    [name: {:via, Registry, {Timesup.GameRegistry, game_id}}] = options
    GenServer.start_link(__MODULE__, GameState.new(game_id), options)
  end

  @impl true
  def init(game) do
    {:ok, game, {:continue, :load_from_database}}
  end

  @impl true
  def handle_continue(:load_from_database, game) do
    game =
      StoredGame
      |> Repo.get(game.id)
      |> case do
        %StoredGame{} = stored_game ->
          StoredGame.to_game_state(stored_game)

        # Nothing in the database -> we'll show the 404 page
        nil ->
          nil
      end

    {:noreply, game}
  end

  def get_game(game_id) do
    GenServer.call(via_tuple(game_id), :game)
  end

  def join(game_id, username) do
    GenServer.call(via_tuple(game_id), {:join, username})
  end

  def add_card(game_id, card, player) do
    GenServer.call(via_tuple(game_id), {:add_card, card, player})
  end

  def set_player_ready(game_id, player) do
    GenServer.call(via_tuple(game_id), {:set_player_ready, player})
  end

  def start_choosing_teams(game_id) do
    GenServer.call(via_tuple(game_id), {:start_choosing_teams})
  end

  def choose_team(game_id, player, team) do
    GenServer.call(via_tuple(game_id), {:choose_team, player, team})
  end

  def start_game(game_id) do
    GenServer.call(via_tuple(game_id), {:start_game})
  end

  def start_turn(game_id) do
    GenServer.call(via_tuple(game_id), {:start_turn})
  end

  def card_guessed(game_id) do
    GenServer.call(via_tuple(game_id), {:card_guessed})
  end

  def pass_card(game_id) do
    GenServer.call(via_tuple(game_id), {:pass_card})
  end

  def start_round(game_id) do
    GenServer.call(via_tuple(game_id), :start_round)
  end

  defp via_tuple(game_id) do
    {:via, Registry, {Timesup.GameRegistry, game_id}}
  end

  # Server (callbacks)

  @impl true
  def handle_call(:game, _from, game) do
    {:reply, game, game}
  end

  @impl true
  def handle_call({:join, username}, _from, game) do
    game
    |> GameState.add_player(username)
    |> write_to_database()
    |> reply()
  end

  @impl true
  def handle_call({:add_card, card, player}, _from, game) do
    game
    |> GameState.add_card(card, player)
    |> write_to_database()
    |> reply()
  end

  @impl true
  def handle_call({:set_player_ready, player}, _from, game) do
    game
    |> GameState.set_player_ready(player)
    |> write_to_database()
    |> reply()
  end

  @impl true
  def handle_call({:start_choosing_teams}, _from, game) do
    game
    |> GameState.start_choosing_teams()
    |> write_to_database()
    |> reply()
  end

  @impl true
  def handle_call({:choose_team, player, team}, _from, game) do
    game
    |> GameState.choose_team(player, team)
    |> write_to_database()
    |> reply()
  end

  @impl true
  def handle_call({:start_game}, _from, game) do
    game
    |> GameState.start_game()
    |> write_to_database()
    |> reply()
  end

  @impl true
  def handle_call({:start_turn}, _from, game) do
    Process.send_after(self(), :tick, 1000)
    game = GameState.start_turn(game)
    {:reply, game, game}
  end

  @impl true
  def handle_call({:card_guessed}, _from, game) do
    Process.send_after(self(), :clear_card_guessed_flash, 200)

    game
    |> GameState.card_guessed()
    |> write_to_database()
    |> reply()
  end

  @impl true
  def handle_call({:pass_card}, _from, game) do
    Process.send_after(self(), :clear_card_passed_flash, 200)

    game
    |> GameState.pass_card()
    |> write_to_database()
    |> reply()
  end

  @impl true
  def handle_call(:start_round, _from, game) do
    game
    |> GameState.start_round()
    |> reply()
  end

  @impl true
  def handle_info(:tick, game) do
    game = GameState.tick(game)

    if game.playing do
      Process.send_after(self(), :tick, 1000)
    end

    TimesupWeb.Endpoint.broadcast(game.id, "update", %{game: game})

    {:noreply, game}
  end

  @impl true
  def handle_info(:clear_card_passed_flash, game) do
    game = GameState.clear_card_passed_flash(game)

    TimesupWeb.Endpoint.broadcast(game.id, "update", %{game: game})

    {:noreply, game}
  end

  @impl true
  def handle_info(:clear_card_guessed_flash, game) do
    game = GameState.clear_card_guessed_flash(game)

    TimesupWeb.Endpoint.broadcast(game.id, "update", %{game: game})

    {:noreply, game}
  end

  def write_to_database(%GameState{} = game) do
    Task.start(fn ->
      Multi.new()
      |> Multi.delete(:delete, StoredGame.from_game_state(game))
      |> Multi.insert(:insert, StoredGame.from_game_state(game))
      |> Timesup.Repo.transaction()
      |> case do
        {:error, failed_operation, failed_value, _} ->
          Logger.error("""
          Could not save game #{game.id} because of #{failed_operation}:
          #{failed_value}
          """)

        _ ->
          nil
      end
    end)

    game
  end

  defp reply(%GameState{} = game) do
    {:reply, game, game}
  end
end
