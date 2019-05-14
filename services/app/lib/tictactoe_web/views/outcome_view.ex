defmodule TictactoeWeb.View.OutcomeView do
  def outcome_message(:draw), do: "Draw"
  def outcome_message(:x_wins), do: "X wins"
  def outcome_message(:o_wins), do: "O wins"
end
