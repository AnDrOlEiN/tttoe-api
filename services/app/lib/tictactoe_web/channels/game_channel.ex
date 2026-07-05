defmodule TictactoeWeb.GameChannel do
  use TictactoeWeb, :channel
  require Logger

  alias Tictactoe.{GameSupervisor, GameServer}
  alias TictactoeWeb.{Endpoint, PresenceTracker}
  alias TictactoeWeb.View.{BoardView, OutcomeView, PlayersView, GameErrorView}

  def join("game:" <> game_id, %{"nickname" => nickname, "sign" => sign}, socket)
      when is_binary(nickname) and is_binary(sign) do
    sign = String.upcase(sign)

    if String.length(nickname) > 0 and sign in ["X", "O", ""] do
      game_id
      |> GameSupervisor.find_or_start_game()
      |> GameServer.add_player(nickname, sign)
      |> case do
        {:ok, player_identifier} ->
          send(self(), {:after_join, game_id})

          {:ok, %{playing_as: player_identifier},
           assign(socket, :playing_as, %{player_identifier => nickname})}

        {:error, error} ->
          {:error, error}
      end
    else
      {:error, "send nickname and sign"}
    end
  end

  def join("game:" <> _game_id, _payload, _socket) do
    {:error, "send nickname and sign"}
  end

  def handle_in("play", %{"x" => x, "y" => y}, %{topic: "game:" <> game_id} = socket)
      when is_integer(x) and is_integer(y) do
    game_pid = GameSupervisor.find_or_start_game(game_id)

    with :ok <- GameServer.play(game_pid, player_sign(socket), [x, y]) do
      broadcast!(socket, "game_update", %{
        current_player: GameServer.playing_now(game_pid),
        board:
          game_pid
          |> GameServer.board()
          |> BoardView.encode_board(),
        move: [x, y]
      })

      {:noreply, socket}
    else
      {:end, outcome, board} ->
        broadcast!(socket, "game_end", %{
          outcome: OutcomeView.outcome_message(outcome),
          board: BoardView.encode_board(board),
          move: [x, y]
        })

        {:noreply, socket}

      {:error, error_identifier} ->
        {:reply, {:error, %{description: GameErrorView.error_message(error_identifier)}}, socket}
    end
  end

  def handle_in("play", _payload, socket) do
    {:reply, {:error, %{description: GameErrorView.error_message(:invalid_payload)}}, socket}
  end

  def handle_in("reset", _, %{topic: "game:" <> game_id} = socket) do
    new_state =
      game_id
      |> GameSupervisor.find_or_start_game()
      |> GameServer.reset()

    broadcast!(socket, "game_start", %{
      current_player: new_state.playing_now,
      board: BoardView.encode_board(new_state.board),
      joined_players: PlayersView.encode_players(new_state.players)
    })

    {:noreply, socket}
  end

  def handle_info({:after_join, game_id}, socket) do
    game_pid = GameSupervisor.find_or_start_game(game_id)

    Process.monitor(game_pid)
    start_game_if_necessary(game_pid, socket)
    track_player_presence(socket)

    {:noreply, socket}
  end

  # The game server stops normally when the last player leaves; a crash
  # means the game state is gone, so close the channel and let the client rejoin.
  def handle_info({:DOWN, _ref, :process, _pid, reason}, socket)
      when reason in [:normal, :shutdown] do
    {:noreply, socket}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:stop, :shutdown, socket}
  end

  def broadcast_left_player(game_topic) do
    Endpoint.broadcast(game_topic, "player_left", %{})
  end

  defp player_sign(socket), do: socket.assigns[:playing_as]

  defp start_game_if_necessary(game_pid, socket) do
    if GameServer.game_ready_to_start?(game_pid) do
      broadcast!(socket, "game_start", %{
        current_player: GameServer.playing_now(game_pid),
        joined_players: game_pid |> GameServer.players() |> PlayersView.encode_players(),
        board:
          game_pid
          |> GameServer.board()
          |> BoardView.encode_board()
      })
    end
  end

  defp track_player_presence(socket) do
    {:ok, _} = PresenceTracker.track_player(socket, player_sign(socket))
  end
end
