defmodule TictactoeWeb.View.BoardView do
  alias Tictactoe.Game.State.Board
  alias Tictactoe.Game.State.Board.Row

  def encode_board(%Board{rows: %{top: top, middle: middle, bottom: bottom}}) do
    %{top: encode_row(top), middle: encode_row(middle), bottom: encode_row(bottom)}
  end

  defp encode_row(%Row{left: left, middle: middle, right: right}) do
    [
      encode_field_state(left),
      encode_field_state(middle),
      encode_field_state(right)
    ]
  end

  defp encode_field_state(field) do
    case field do
      :empty -> ""
      "X" -> "X"
      "O" -> "O"
      unknown -> raise "Trying to encode unknown field: #{inspect(unknown)}"
    end
  end
end
