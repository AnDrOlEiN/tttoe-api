defmodule Tictactoe.Game.State.Board do
  alias Tictactoe.Game.State.BoardField
  alias Tictactoe.Game.State.Board.Row

  defstruct rows: %{
              top: %Row{},
              middle: %Row{},
              bottom: %Row{}
            }

  def empty do
    %__MODULE__{}
  end

  def set_field(board = %__MODULE__{}, player, [x, y]) do
    with :ok <- verify_valid_position(x, y),
         :ok <- verify_field_unused(board, x, y) do
      new_board = %__MODULE__{
        rows: put_in(board.rows, [row_at(y), Row.field_at(x)], player)
      }

      {:ok, new_board}
    end
  end

  def value_at(%__MODULE__{rows: rows}, x, y) do
    get_in(rows, [row_at(y), Row.field_at(x)])
  end

  defp verify_valid_position(x, y) do
    if x >= 0 && x <= 2 && y >= 0 && y <= 2 do
      :ok
    else
      {:error, :invalid_position}
    end
  end

  defp verify_field_unused(%__MODULE__{} = board, x, y) do
    if value_at(board, x, y) == BoardField.empty() do
      :ok
    else
      {:error, :field_used_already}
    end
  end

  defp row_at(0), do: Access.key!(:bottom)
  defp row_at(1), do: Access.key!(:middle)
  defp row_at(2), do: Access.key!(:top)
end
