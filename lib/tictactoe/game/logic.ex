defmodule Tictactoe.Game.Logic do
  alias Tictactoe.Game.{State, Logic.GameEnding}

  def play(%State{} = state, player, position) do
    with :ok <- State.JoinedPlayers.verify_complete(state.players),
         :ok <- verify_players_turn(state.playing_now, player),
         {:ok, new_board} <- State.Board.set_field(state.board, player |> Map.keys() |> List.first(), position) do
      new_state =
        state
        |> Map.put(:board, new_board)
        |> switch_playing_now()

      if game_ended?(new_state) do
        {:end, winner(new_state), new_state}
      else
        {:ok, new_state}
      end
    end
  end

  def reset(state), do: %State{state | board: State.Board.empty()}

  defp verify_players_turn(playing, trying_to_play),
    do:
      if(Map.has_key?(trying_to_play, playing) == true, do: :ok, else: {:error, :not_players_turn})

  defp switch_playing_now(state = %State{playing_now: "X"}), do: %State{state | playing_now: "O"}
  defp switch_playing_now(state = %State{playing_now: "O"}), do: %State{state | playing_now: "X"}

  defp game_ended?(%State{board: board}) do
    GameEnding.game_ended?(board)
  end

  defp winner(%State{board: board}) do
    GameEnding.outcome(board)
  end
end
