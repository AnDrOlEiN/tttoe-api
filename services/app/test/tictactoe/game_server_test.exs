defmodule Tictactoe.GameServerTest do
  use ExUnit.Case, async: true
  alias Tictactoe.GameServer
  alias Tictactoe.Game.State.Board.Row

  setup :start_game_server

  describe ".add_player" do
    test "first assigns X", %{server: pid} do
      returned_value = GameServer.add_player(pid, "foo", "X")

      assert(returned_value == {:ok, "X"})
    end

    test "then assigns O", %{server: pid} do
      GameServer.add_player(pid, "foo", "")
      returned_value = GameServer.add_player(pid, "bar", "")

      assert(returned_value == {:ok, "O"})
    end

    test "then errors", %{server: pid} do
      GameServer.add_player(pid, "foo", "O")
      GameServer.add_player(pid, "bar", "X")
      returned_value = GameServer.add_player(pid, "nope", "")

      assert(returned_value == {:error, :game_full})
    end
  end

  describe ".remove_player" do
    test "errors when the player is not joined", %{server: pid} do
      assert(GameServer.remove_player(pid, "X") == {:error, :player_not_joined})
    end

    test "returns :ok when the player is joined", %{server: pid} do
      {:ok, _} = GameServer.add_player(pid, "foo", "O")
      assert(GameServer.remove_player(pid, %{"O" => "foo"}) == :ok)
    end
  end

  describe ".play with incomplete players" do
    test "errors when no two players", %{server: pid} do
      assert(GameServer.play(pid, %{"X" => "nope"}, [1, 1]) == {:error, :game_not_full})
    end
  end

  describe ".play with all players joined (player ordering)" do
    setup :join_all_players

    test "it rejects the move if it's not the players turn", %{server: pid} do
      assert(GameServer.play(pid, %{"O" => "foo"}, [1, 1]) == {:error, :not_players_turn})
    end

    test "the same player cannot play twice in a row", %{server: pid} do
      assert(:ok == GameServer.play(pid, %{"X" => "bar"}, [1, 1]))
      assert({:error, :not_players_turn} == GameServer.play(pid, %{"X" => "bar"}, [1, 2]))
    end
  end

  describe ".play with all players joined (board field collision)" do
    setup :join_all_players

    test "it does not allow using the same field twice", %{server: pid} do
      assert(:ok == GameServer.play(pid, %{"X" => "bar"}, [1, 1]))
      assert({:error, :field_used_already} == GameServer.play(pid, %{"O" => "foo"}, [1, 1]))
    end

    test "it works for other fields", %{server: pid} do
      assert(:ok == GameServer.play(pid, %{"X" => "bar"}, [1, 1]))
      assert(:ok == GameServer.play(pid, %{"O" => "foo"}, [1, 2]))
    end
  end

  describe ".play with a player winning" do
    setup :join_all_players

    test "game ends", %{server: pid} do
      assert(:ok == GameServer.play(pid, %{"X" => "bar"}, [0, 0]))
      assert(:ok == GameServer.play(pid, %{"O" => "foo"}, [1, 0]))
      assert(:ok == GameServer.play(pid, %{"X" => "bar"}, [0, 1]))
      assert(:ok == GameServer.play(pid, %{"O" => "foo"}, [1, 1]))

      expected_board = %Tictactoe.Game.State.Board{
        rows: %{
          top: %Row{left: "X", middle: :empty, right: :empty},
          middle: %Row{left: "X", middle: "O", right: :empty},
          bottom: %Row{left: "X", middle: "O", right: :empty}
        }
      }

      assert({:end, :x_wins, expected_board} == GameServer.play(pid, %{"X" => "bar"}, [0, 2]))
    end
  end

  describe ".play with a draw" do
    setup :join_all_players

    test "game ends", %{server: pid} do
      assert(:ok == GameServer.play(pid, %{"X" => "bar"}, [0, 0]))
      assert(:ok == GameServer.play(pid, %{"O" => "foo"}, [0, 1]))
      assert(:ok == GameServer.play(pid, %{"X" => "bar"}, [0, 2]))
      assert(:ok == GameServer.play(pid, %{"O" => "foo"}, [1, 1]))
      assert(:ok == GameServer.play(pid, %{"X" => "bar"}, [1, 2]))
      assert(:ok == GameServer.play(pid, %{"O" => "foo"}, [2, 2]))
      assert(:ok == GameServer.play(pid, %{"X" => "bar"}, [1, 0]))
      assert(:ok == GameServer.play(pid, %{"O" => "foo"}, [2, 0]))

      expected_board = %Tictactoe.Game.State.Board{
        rows: %{
          top: %Row{left: "X", middle: "X", right: "O"},
          middle: %Row{left: "O", middle: "O", right: "X"},
          bottom: %Row{left: "X", middle: "X", right: "O"}
        }
      }

      assert({:end, :draw, expected_board} == GameServer.play(pid, %{"X" => "bar"}, [2, 1]))
    end
  end

  defp start_game_server(_) do
    {:ok, pid} = GameServer.start_link()

    {:ok, server: pid}
  end

  defp join_all_players(%{server: pid}) do
    {:ok, "X"} = GameServer.add_player(pid, "X", "bar")
    {:ok, "O"} = GameServer.add_player(pid, "O", "foo")
    :ok
  end
end
