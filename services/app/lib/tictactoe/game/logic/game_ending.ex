defmodule Tictactoe.Game.Logic.GameEnding do
  alias Tictactoe.Game.State.{Board, BoardField}

  @vertical_winning_lines [
    [[0, 0], [0, 1], [0, 2]],
    [[1, 0], [1, 1], [1, 2]],
    [[2, 0], [2, 1], [2, 2]]
  ]

  @horizontal_winning_lines [
    [[0, 0], [1, 0], [2, 0]],
    [[0, 1], [1, 1], [2, 1]],
    [[0, 2], [1, 2], [2, 2]]
  ]

  @diagonal_winning_lines [
    [[0, 0], [1, 1], [2, 2]],
    [[2, 0], [1, 1], [0, 2]]
  ]
  def game_ended?(%Board{} = board) do
    outcome(board) != :none
  end

  def outcome(%Board{} = board) do
    with nil <- vertical_winner(board),
         nil <- horizontal_winner(board),
         nil <- diagonal_winner(board),
         nil <- check_draw(board) do
      :none
    end
  end

  defp check_draw(%Board{} = board) do
    for x <- [0, 1, 2],
        y <- [0, 1, 2] do
      Board.value_at(board, x, y)
    end
    |> Enum.all?(fn field_value ->
      field_value != BoardField.empty()
    end)
    |> if do
      :draw
    else
      nil
    end
  end

  defp vertical_winner(board) do
    find_winner(board, @vertical_winning_lines)
  end

  defp horizontal_winner(board) do
    find_winner(board, @horizontal_winning_lines)
  end

  defp diagonal_winner(board) do
    find_winner(board, @diagonal_winning_lines)
  end

  defp find_winner(board, lines) do
    Enum.find_value(lines, fn coordinates ->
      winner(board, coordinates)
    end)
  end

  defp winner(board, coordinates) do
    field_values =
      coordinates
      |> Enum.map(fn [x, y] ->
        Board.value_at(board, x, y)
      end)
      |> Enum.uniq()

    case field_values do
      [field_value] ->
        if field_value == BoardField.empty() do
          nil
        else
          field_value
        end

      _ ->
        false
    end
  end
end
