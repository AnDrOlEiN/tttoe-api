defmodule Tictactoe.Game.State.Board.Row do
  alias Tictactoe.Game.State.BoardField

  defstruct left: BoardField.empty(), middle: BoardField.empty(), right: BoardField.empty()

  def field_at(0), do: Access.key!(:left)
  def field_at(1), do: Access.key!(:middle)
  def field_at(2), do: Access.key!(:right)
end
