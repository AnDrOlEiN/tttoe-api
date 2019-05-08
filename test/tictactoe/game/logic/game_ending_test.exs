defmodule Tictactoe.Game.Logic.GameEndingTest do
  use ExUnit.Case, async: true
  alias Tictactoe.Game.State.Board
  alias Tictactoe.Game.Logic.GameEnding

  describe ".game_ended?" do
    test "empty field is false" do
      result = Board.empty() |> GameEnding.game_ended?()
      assert(result == false)
    end

    test "vertical line is true" do
      assert_game_ended([0, 0], [0, 1], [0, 2])
      assert_game_ended([1, 0], [1, 1], [1, 2])
      assert_game_ended([2, 0], [2, 1], [2, 2])
    end

    test "horizontal line is true" do
      assert_game_ended([0, 0], [1, 0], [2, 0])
      assert_game_ended([0, 1], [1, 1], [2, 1])
      assert_game_ended([0, 2], [1, 2], [2, 2])
    end

    test "diagonal line is true" do
      assert_game_ended([0, 0], [1, 1], [2, 2])
    end

    test "other diagonal line" do
      assert_game_ended([2, 0], [1, 1], [0, 2])
    end
  end

  defp assert_game_ended(first_coordinate, second_coordinate, third_coordinate) do
    result =
      with empty_board = %Board{} <- Board.empty(),
           {:ok, first} <- Board.set_field(empty_board, "X", first_coordinate),
           {:ok, second} <- Board.set_field(first, "X", second_coordinate),
           {:ok, third} <- Board.set_field(second, "X", third_coordinate) do
        GameEnding.game_ended?(third)
      end

    assert(result == true)
  end
end
