defmodule Tictactoe.Game.State.JoinedPlayersTest do
  use ExUnit.Case, async: true
  require Logger
  alias Tictactoe.Game.State.JoinedPlayers

  describe ".add_player" do
    test "adds X to an empty player set" do
      {:ok, added_player, _} = JoinedPlayers.none() |> JoinedPlayers.add_player("foo", "X")

      assert(added_player == "X")
    end

    test "adds X then O" do
      x_joined_players =
        JoinedPlayers.none()
        |> add_player!("foo", "X")

      with {:ok, added_player, _} <- JoinedPlayers.add_player(x_joined_players) do
        assert(added_player == "O")
      end
    end

    test "errors when trying to add to a full game" do
      full_players =
        JoinedPlayers.none()
        |> add_player!("foo", "X")
        |> add_player!("bar", "Y")

      result = JoinedPlayers.add_player(full_players, "foobar", "")
      assert(result == {:error, :game_full})
    end

    test "re-adds X when removed" do
      {:ok, next_added_player, _} =
        JoinedPlayers.none()
        |> add_player!("foo", "X")
        |> remove_player!(%{"X" => "foo"})
        |> JoinedPlayers.add_player("bar", "")

      assert(next_added_player == "X")
    end

    test "re-adds O when removed" do
      # JoinedPlayers.none()
      # |> add_player!("foo", "X")
      # |> add_player!("bar", "O")
      # |> remove_player!(%{"O" => "bar"})
      # |> inspect
      # |> Logger.warn
      {:ok, next_added_player, _} =
        JoinedPlayers.none()
        |> add_player!("exs", "X")
        |> add_player!("zero", "O")
        |> remove_player!(%{"O" => "zero"})
        |> JoinedPlayers.add_player("foobar", "")

      assert(next_added_player == "O")
    end
  end

  describe ".remove_player" do
    test "errors on an empty player set" do
      result = JoinedPlayers.none() |> JoinedPlayers.remove_player(%{"X" => "foo"})

      assert(result == {:error, :player_not_joined})
    end

    test "removes X" do
      result =
        JoinedPlayers.none()
        |> add_player!("removes_x", "X")
        |> JoinedPlayers.remove_player(%{"X" => "removes_x"})

      assert(result == {:ok, JoinedPlayers.none()})
    end

    test "removes O" do
      x_only = JoinedPlayers.none() |> add_player!("foo", "X")

      result = x_only |> add_player!("bar", "O") |> JoinedPlayers.remove_player(%{"O" => "bar"})

      assert(result == {:ok, x_only})
    end
  end

  describe ".verify_complete" do
    test "errors when the game is empty" do
      assert(JoinedPlayers.verify_complete(JoinedPlayers.none()) == {:error, :game_not_full})
    end

    test "errors when only one player is joined" do
      result =
        JoinedPlayers.none()
        |> add_player!("foo", "X")
        |> JoinedPlayers.verify_complete()

      assert(result == {:error, :game_not_full})
    end

    test "returns :ok on full game" do
      result =
        JoinedPlayers.none()
        |> add_player!("foo", "O")
        |> add_player!("bar", "X")
        |> JoinedPlayers.verify_complete()

      assert(result == :ok)
    end
  end

  defp add_player!(players, nickname, sign, expected_player \\ nil) do
    {:ok, joined_player, players_after_join} = JoinedPlayers.add_player(players, nickname, sign)

    if expected_player do
      assert(joined_player == expected_player)
    end
    players_after_join
  end

  defp remove_player!(players, player_map) do
    {:ok, players_after_remove} = JoinedPlayers.remove_player(players, player_map)
    players_after_remove
  end
end
