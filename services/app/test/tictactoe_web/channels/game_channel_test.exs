defmodule TictactoeWeb.GameChannelTest do
  use TictactoeWeb.ChannelCase

  alias Tictactoe.{GameServer, GameSupervisor}
  alias TictactoeWeb.{GameChannel, PresenceTracker}

  setup [:start_supervisor, :start_presence_tracker]

  describe "joining a game" do
    test "rejects a payload without nickname and sign" do
      assert({:error, "send nickname and sign"} == join_raw(%{}))
      assert({:error, "send nickname and sign"} == join_raw(%{"nickname" => "alice"}))
      assert({:error, "send nickname and sign"} == join_raw(%{"sign" => "x"}))
    end

    test "rejects non-string nickname or sign" do
      assert({:error, "send nickname and sign"} == join_raw(%{"nickname" => nil, "sign" => "x"}))
      assert({:error, "send nickname and sign"} == join_raw(%{"nickname" => 123, "sign" => "x"}))
      assert({:error, "send nickname and sign"} == join_raw(%{"nickname" => "alice", "sign" => 1}))
    end

    test "rejects an empty nickname and unknown signs" do
      assert({:error, "send nickname and sign"} == join_raw(%{"nickname" => "", "sign" => "x"}))
      assert({:error, "send nickname and sign"} == join_raw(%{"nickname" => "alice", "sign" => "z"}))
    end

    test "assigns the requested sign for lowercase input" do
      assert({:ok, %{playing_as: "O"}, _socket} = join_player("o", "solo"))
    end

    test "rejects a duplicate nickname" do
      {:ok, _, _} = join_player("x", "dup")

      assert({:error, :nickname_taken} == join_player("o", "dup"))
    end
  end

  describe "a half-full Tictactoe game" do
    test "rejects play moves" do
      {:ok, _, x_socket} = join_player("x", "bar")

      ref = push(x_socket, "play", %{x: 1, y: 1})
      assert_reply(ref, :error, %{description: "Game not full yet!"})
    end

    test "still broadcasts a game_start on reset" do
      {:ok, _, x_socket} = join_player("x", "bar")

      push(x_socket, "reset")

      assert_broadcast("game_start", %{
        board: %{top: ["", "", ""], middle: ["", "", ""], bottom: ["", "", ""]},
        joined_players: %{"X" => "bar"}
      })
    end
  end

  describe "a player leaving a half-full game" do
    setup [:join_one_player, :get_game_server_pid]

    test "terminates the game server", %{x_socket: socket, server_pid: pid} do
      ref = Process.monitor(pid)
      leave(socket)

      assert_receive({:DOWN, ^ref, _, _, _})
    end
  end

  describe "a player leaving a full game" do
    setup [:join_two_players, :get_game_server_pid]

    test "does not terminate the game server", %{x_socket: socket, server_pid: pid} do
      ref = Process.monitor(pid)

      leave(socket)

      refute_receive({:DOWN, ^ref, _, _, _})
    end

    test "broadcasts a message", %{x_socket: socket} do
      leave(socket)

      assert_broadcast("player_left", %{})
    end
  end

  describe "the first player joining" do
    test "does not broadcast a game_start event" do
      {:ok, _, _} = join_player("x", "bar")

      refute_broadcast("game_start", %{})
    end
  end

  describe "the last player joining" do
    test "broadcasts a game_start event with all necessary information" do
      {:ok, _, _} = join_player("x", "bar")
      {:ok, _, _} = join_player("o", "foo")

      assert_broadcast("game_start", %{
        current_player: current_player,
        board: %{top: ["", "", ""], middle: ["", "", ""], bottom: ["", "", ""]},
        joined_players: %{"X" => "bar", "O" => "foo"}
      })

      assert(current_player in ["X", "O"])
    end
  end

  describe "a full Tictactoe game" do
    setup [:join_two_players, :get_game_server_pid, :identify_turn_order]

    test "does not allow any more players to join" do
      assert({:error, :game_full} == join_player("", "foobar"))
    end

    test "it rejects the wrong player playing a move", %{sockets: sockets, second: second} do
      ref = play_move(sockets[second], 1, 1)
      assert_reply(ref, :error, %{description: "Not your turn!"})
    end

    test "it accepts the right player making a move", %{
      sockets: sockets,
      first: first,
      second: second
    } do
      play_move(sockets[first], 1, 1)

      assert_broadcast("game_update", %{
        current_player: ^second,
        board: %{top: ["", "", ""], middle: ["", ^first, ""], bottom: ["", "", ""]},
        move: [1, 1]
      })
    end

    test "it rejects out-of-range coordinates", %{sockets: sockets, first: first} do
      ref = play_move(sockets[first], 5, 5)
      assert_reply(ref, :error, %{description: "Invalid field coordinate!"})
    end

    test "it rejects playing an occupied field", %{
      server_pid: pid,
      sockets: sockets,
      first: first,
      second: second
    } do
      :ok = server_play(pid, first, [1, 1])

      ref = play_move(sockets[second], 1, 1)
      assert_reply(ref, :error, %{description: "Field used already!"})
    end

    test "it rejects a malformed play payload", %{sockets: sockets, first: first} do
      ref = push(sockets[first], "play", %{x: "1", y: 1})
      assert_reply(ref, :error, %{description: "Send integer x and y coordinates!"})

      ref = push(sockets[first], "play", %{})
      assert_reply(ref, :error, %{description: "Send integer x and y coordinates!"})
    end

    test "it makes reset correctly", %{sockets: sockets, first: first} do
      reset(sockets[first])

      assert_broadcast("game_start", %{
        current_player: current_player,
        board: %{top: ["", "", ""], middle: ["", "", ""], bottom: ["", "", ""]},
        joined_players: %{"X" => "foo", "O" => "bar"}
      })

      assert(current_player in ["X", "O"])
    end
  end

  describe "game endings" do
    setup [:join_two_players, :get_game_server_pid, :identify_turn_order]

    test "the first player winning", %{
      server_pid: pid,
      sockets: sockets,
      first: first,
      second: second
    } do
      :ok = server_play(pid, first, [0, 0])
      :ok = server_play(pid, second, [1, 0])
      :ok = server_play(pid, first, [0, 1])
      :ok = server_play(pid, second, [1, 1])

      play_move(sockets[first], 0, 2)

      expected_outcome = "#{first} wins"

      assert_broadcast("game_end", %{outcome: ^expected_outcome, board: board, move: [0, 2]})
      assert(board == %{top: [first, "", ""], middle: [first, second, ""], bottom: [first, second, ""]})
    end

    test "the second player winning", %{
      server_pid: pid,
      sockets: sockets,
      first: first,
      second: second
    } do
      :ok = server_play(pid, first, [0, 0])
      :ok = server_play(pid, second, [0, 1])
      :ok = server_play(pid, first, [1, 0])
      :ok = server_play(pid, second, [1, 1])
      :ok = server_play(pid, first, [0, 2])

      play_move(sockets[second], 2, 1)

      expected_outcome = "#{second} wins"

      assert_broadcast("game_end", %{outcome: ^expected_outcome, board: board, move: [2, 1]})
      assert(board == %{top: [first, "", ""], middle: [second, second, second], bottom: [first, first, ""]})
    end

    test "draw", %{server_pid: pid, sockets: sockets, first: first, second: second} do
      :ok = server_play(pid, first, [0, 0])
      :ok = server_play(pid, second, [0, 1])
      :ok = server_play(pid, first, [0, 2])
      :ok = server_play(pid, second, [1, 1])
      :ok = server_play(pid, first, [1, 2])
      :ok = server_play(pid, second, [2, 2])
      :ok = server_play(pid, first, [1, 0])
      :ok = server_play(pid, second, [2, 0])

      play_move(sockets[first], 2, 1)

      assert_broadcast("game_end", %{outcome: "Draw", board: board})
      assert(board == %{top: [first, first, second], middle: [second, second, first], bottom: [first, first, second]})
    end

    test "moves after the game ended are rejected", %{
      server_pid: pid,
      sockets: sockets,
      first: first,
      second: second
    } do
      win_game(pid, sockets, first, second)

      ref = play_move(sockets[second], 2, 2)
      assert_reply(ref, :error, %{description: "Game ended already!"})
    end

    test "reset after the game ended starts a fresh game with the same players", %{
      server_pid: pid,
      sockets: sockets,
      first: first,
      second: second
    } do
      win_game(pid, sockets, first, second)

      reset(sockets[second])

      assert_broadcast("game_start", %{
        board: %{top: ["", "", ""], middle: ["", "", ""], bottom: ["", "", ""]},
        joined_players: %{"X" => "foo", "O" => "bar"}
      })
    end
  end

  defp play_move(player_socket, x, y) do
    push(player_socket, "play", %{x: x, y: y})
  end

  defp server_play(pid, sign, position) do
    GameServer.play(pid, %{sign => nickname(sign)}, position)
  end

  defp win_game(pid, sockets, first, second) do
    :ok = server_play(pid, first, [0, 0])
    :ok = server_play(pid, second, [1, 0])
    :ok = server_play(pid, first, [0, 1])
    :ok = server_play(pid, second, [1, 1])

    play_move(sockets[first], 0, 2)
    assert_broadcast("game_end", %{})
  end

  defp nickname("X"), do: "foo"
  defp nickname("O"), do: "bar"

  defp join_player(player_mark, player_name) do
    join_raw(%{"nickname" => player_name, "sign" => player_mark})
  end

  defp join_raw(payload) do
    socket("test", %{}) |> subscribe_and_join(GameChannel, "game:foo", payload)
  end

  defp reset(player_socket) do
    push(player_socket, "reset")
  end

  defp join_one_player(context) do
    {:ok, _, x_socket} = join_player("x", "bar")

    context
    |> Map.put(:x_socket, x_socket)
  end

  defp join_two_players(context) do
    {:ok, _, x_socket} = join_player("x", "foo")
    {:ok, _, o_socket} = join_player("o", "bar")

    context
    |> Map.put(:x_socket, x_socket)
    |> Map.put(:o_socket, o_socket)
    |> Map.put(:sockets, %{"X" => x_socket, "O" => o_socket})
  end

  defp identify_turn_order(%{server_pid: pid} = context) do
    first = GameServer.playing_now(pid)
    second = opposite(first)

    context
    |> Map.put(:first, first)
    |> Map.put(:second, second)
  end

  defp opposite("X"), do: "O"
  defp opposite("O"), do: "X"

  defp get_game_server_pid(context) do
    pid = GameSupervisor.whereis_game("foo")

    context
    |> Map.put(:server_pid, pid)
  end

  # start_supervised! tears these down synchronously between tests,
  # preventing a test from grabbing the dying supervisor of the previous one.
  defp start_supervisor(context) do
    start_supervised!(%{id: GameSupervisor, start: {GameSupervisor, :start_link, []}})
    context
  end

  defp start_presence_tracker(context) do
    start_supervised!(%{id: PresenceTracker, start: {PresenceTracker, :start_link, []}})
    context
  end
end
