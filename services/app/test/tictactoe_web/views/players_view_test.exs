defmodule TictactoeWeb.View.PlayersViewTest do
  use ExUnit.Case, async: true

  alias Tictactoe.Game.State.JoinedPlayers
  alias TictactoeWeb.View.PlayersView

  test "encodes two joined players into a single sign-to-nickname map" do
    {:ok, "X", players} = JoinedPlayers.add_player(JoinedPlayers.none(), "alice", "X")
    {:ok, "O", players} = JoinedPlayers.add_player(players, "bob", "O")

    assert PlayersView.encode_players(players) == %{"X" => "alice", "O" => "bob"}
  end

  test "encodes a single joined player" do
    {:ok, "X", players} = JoinedPlayers.add_player(JoinedPlayers.none(), "alice", "X")

    assert PlayersView.encode_players(players) == %{"X" => "alice"}
  end

  test "encodes no players as an empty map" do
    assert PlayersView.encode_players(JoinedPlayers.none()) == %{}
  end
end
