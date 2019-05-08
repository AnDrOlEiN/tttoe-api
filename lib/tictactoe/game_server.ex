defmodule Tictactoe.GameServer do
  use GenServer
  alias Tictactoe.{Game, GameSupervisor}

  def start_link do
    GenServer.start_link(__MODULE__, Game.State.initial())
  end

  def start_link(game_id) when is_binary(game_id), do: game_id |> String.to_atom() |> start_link

  def start_link(game_id) do
    GenServer.start_link(__MODULE__, Game.State.initial(), name: game_id)
  end

  # Public API
  def add_player(game), do: GenServer.call(game, :add_player)

  def remove_player(game, player_sign), do: GenServer.call(game, {:remove_player, player_sign})

  def players(game), do: GenServer.call(game, :get_players)

  def board(game), do: GenServer.call(game, :get_board)

  def play(game, player, position), do: GenServer.call(game, {:play, player, position})

  def playing_now(game), do: GenServer.call(game, :get_playing_now)

  def game_empty?(game) do
    game
    |> players()
    |> Game.State.JoinedPlayers.empty?()
  end

  def stop_if_empty(game) do
    if game_empty?(game) do
      GameSupervisor.stop_game(game)
      :stopped
    else
      :not_stopped
    end
  end

  def game_ready_to_start?(game) do
    game |> players() |> Game.State.JoinedPlayers.verify_complete() == :ok
  end

  def game_ended?(game) do
    case game |> board |> Game.Logic.GameEnding.outcome() do
      :none -> {:error, :not_ended}
      :draw -> {:ok, :draw}
      "X" -> {:ok, :x_wins}
      "Y" -> {:ok, :y_wins}
    end
  end

  # GenServer callbacks
  def handle_call(:add_player, _, state) do
    with {:ok, player_identifier, new_state} <- Game.State.add_player(state) do
      {:reply, {:ok, player_identifier}, new_state}
    else
      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:remove_player, player_sign}, _, state) do
    with {:ok, new_state} <- Game.State.remove_player(state, player_sign) do
      {:reply, :ok, new_state}
    else
      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:get_players, _, state) do
    {:reply, Game.State.players(state), state}
  end

  def handle_call(:get_board, _, state) do
    {:reply, Game.State.board(state), state}
  end

  def handle_call(:get_playing_now, _, state) do
    {:reply, Game.State.playing_now(state), state}
  end

  def handle_call({:play, player, position}, _, state) do
    with {:ok, new_game_state} <- Game.Logic.play(state, player, position) do
      {:reply, :ok, new_game_state}
    else
      {:end, outcome, end_state} ->
        {:stop, :normal, {:end, outcome_message(outcome), Game.State.board(end_state)}, :ok}

      error ->
        {:reply, error, state}
    end
  end

  defp outcome_message("X"), do: :x_wins
  defp outcome_message("O"), do: :o_wins
  defp outcome_message(:draw), do: :draw
end
