defmodule TictactoeWeb.View.GameErrorView do
  def error_message(:game_not_full), do: "Game not full yet!"
  def error_message(:not_players_turn), do: "Not your turn!"
  def error_message(:invalid_position), do: "Invalid field coordinate!"
  def error_message(:field_used_already), do: "Field used already!"
  def error_message(:game_ended), do: "Game ended already!"
  def error_message(:invalid_payload), do: "Send integer x and y coordinates!"
end
