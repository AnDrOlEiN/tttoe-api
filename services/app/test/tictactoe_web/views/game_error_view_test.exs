defmodule TictactoeWeb.View.GameErrorViewTest do
  use ExUnit.Case, async: true

  alias TictactoeWeb.View.GameErrorView

  test "maps every game error to a user-facing message" do
    assert GameErrorView.error_message(:game_not_full) == "Game not full yet!"
    assert GameErrorView.error_message(:not_players_turn) == "Not your turn!"
    assert GameErrorView.error_message(:invalid_position) == "Invalid field coordinate!"
    assert GameErrorView.error_message(:field_used_already) == "Field used already!"
    assert GameErrorView.error_message(:game_ended) == "Game ended already!"
    assert GameErrorView.error_message(:invalid_payload) == "Send integer x and y coordinates!"
  end
end
