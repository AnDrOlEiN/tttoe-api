defmodule TictactoeWeb.View.PlayersView do
  alias Tictactoe.Game.State.JoinedPlayers

  @doc """
  Encodes joined players as a single sign-to-nickname map,
  e.g. %{"X" => "alice", "O" => "bob"}.
  """
  def encode_players(%JoinedPlayers{players: players}) do
    Enum.reduce(players, %{}, &Map.merge(&2, &1))
  end
end
