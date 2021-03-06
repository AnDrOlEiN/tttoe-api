defmodule Tictactoe.Game.State do
  alias Tictactoe.Game.State.{Board, JoinedPlayers}
  defstruct players: JoinedPlayers.none(), board: Board.empty(), playing_now: JoinedPlayers.select_player_randomly()

  def initial, do: %__MODULE__{}

  def players(%__MODULE__{players: players}), do: players
  def board(%__MODULE__{board: board}), do: board

  def add_player(current = %__MODULE__{players: players}, nickname, sign) do
    with {:ok, added_player, new_players} <- JoinedPlayers.add_player(players, nickname, sign) do
      {:ok, added_player, %__MODULE__{current | players: new_players}}
    end
  end

  def remove_player(current = %__MODULE__{players: players}, player_map) do
    with {:ok, new_players} <- JoinedPlayers.remove_player(players, player_map) do
      {:ok, %__MODULE__{current | players: new_players}}
    end
  end

  def playing_now(%__MODULE__{playing_now: playing_now}), do: playing_now
end
