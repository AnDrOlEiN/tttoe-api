defmodule TictactoeWeb.GameChannelTest do
  use TictactoeWeb.ChannelCase

  alias Tictactoe.{GameServer, GameSupervisor}
  alias TictactoeWeb.{GameChannel, PresenceTracker}

  setup [:start_supervisor, :start_presence_tracker]

  describe "a half-full Tictactoe game" do
    test "rejects play moves" do
      {:ok, _, x_socket} = join_player("x", "bar")

      ref = push(x_socket, "play", %{x: 1, y: 1})
      assert_reply(ref, :error, %{description: "Game not full yet!"})
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

      refute_broadcast("game_start", %{
        current_player: "X",
        board: %{top: ["", "", ""], middle: ["", "", ""], bottom: ["", "", ""]}
      })
    end
  end

  describe "the last player joining" do
    test "broadcasts a game_start event with all necessary information" do
      {:ok, _, _} = join_player("x", "bar")
      {:ok, _, _} = join_player("o", "foo")

      assert_broadcast("game_start", %{
        current_player: "X",
        board: %{top: ["", "", ""], middle: ["", "", ""], bottom: ["", "", ""]}
      })
    end
  end

  describe "a full Tictactoe game" do
    setup [:join_two_players]

    test "does not allow any more players to join" do
      assert({:error, :game_full} == join_player("", "foobar"))
    end

    test "it rejects the wrong player playing a move", %{
      o_socket: o_socket
    } do
      # O plays, is not allowed to
      ref = play_move(o_socket, 1, 1)
      assert_reply(ref, :error, %{description: "Not your turn!"})
    end

    test "it accepts the right player making a move", %{x_socket: x_socket} do
      ref = play_move(x_socket, 1, 1)
      assert_reply(ref, :ok)

      assert_broadcast("game_update", %{
        current_player: "O",
        board: %{top: ["", "", ""], middle: ["", "X", ""], bottom: ["", "", ""]}
      })
    end

    test "it makes reset correctly", %{x_socket: x_socket} do
      ref = reset(x_socket)
      assert_reply(ref, :ok)

      assert_broadcast("game_start", %{
        current_player: "X",
        board: %{top: ["", "", ""], middle: ["", "", ""], bottom: ["", "", ""]}
      })
    end
  end

  describe "game endings" do
    setup [:join_two_players, :get_game_server_pid]

    test "X winning", %{x_socket: x_socket, server_pid: pid} do
      :ok = GameServer.play(pid, %{"X" => "bar"}, [0, 0])
      :ok = GameServer.play(pid, %{"O" => "foo"}, [1, 0])
      :ok = GameServer.play(pid, %{"X" => "bar"}, [0, 1])
      :ok = GameServer.play(pid, %{"O" => "foo"}, [1, 1])

      play_move(x_socket, 0, 2)

      assert_broadcast("game_end", %{
        outcome: "X wins",
        board: %{top: ["X", "", ""], middle: ["X", "O", ""], bottom: ["X", "O", ""]}
      })
    end

    test "O winning", %{o_socket: o_socket, server_pid: pid} do
      :ok = GameServer.play(pid, %{"X" => "bar"}, [0, 0])
      :ok = GameServer.play(pid, %{"O" => "foo"}, [0, 1])
      :ok = GameServer.play(pid, %{"X" => "bar"}, [1, 0])
      :ok = GameServer.play(pid, %{"O" => "foo"}, [1, 1])
      :ok = GameServer.play(pid, %{"X" => "bar"}, [0, 2])

      play_move(o_socket, 2, 1)

      assert_broadcast("game_end", %{
        outcome: "O wins",
        board: %{top: ["X", "", ""], middle: ["O", "O", "O"], bottom: ["X", "X", ""]}
      })
    end

    test "draw", %{x_socket: x_socket, server_pid: pid} do
      :ok = GameServer.play(pid, %{"X" => "bar"}, [0, 0])
      :ok = GameServer.play(pid, %{"O" => "foo"}, [0, 1])
      :ok = GameServer.play(pid, %{"X" => "bar"}, [0, 2])
      :ok = GameServer.play(pid, %{"O" => "foo"}, [1, 1])
      :ok = GameServer.play(pid, %{"X" => "bar"}, [1, 2])
      :ok = GameServer.play(pid, %{"O" => "foo"}, [2, 2])
      :ok = GameServer.play(pid, %{"X" => "bar"}, [1, 0])
      :ok = GameServer.play(pid, %{"O" => "foo"}, [2, 0])

      play_move(x_socket, 2, 1)

      assert_broadcast("game_end", %{
        outcome: "Draw",
        board: %{top: ["X", "X", "O"], middle: ["O", "O", "X"], bottom: ["X", "X", "O"]}
      })
    end
  end

  defp play_move(player_socket, x, y) do
    push(player_socket, "play", %{x: x, y: y})
  end

  defp join_player(player_mark, player_name) do
    socket(player_mark, %{}) |> subscribe_and_join(GameChannel, "game:foo", %{"nickname" => player_name, "sign" => player_mark})
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
  end

  defp get_game_server_pid(context) do
    {:error, {:already_started, pid}} = GameServer.start_link("foo")

    context
    |> Map.put(:server_pid, pid)
  end

  defp start_supervisor(context) do
    GameSupervisor.start_link()
    context
  end

  defp start_presence_tracker(context) do
    PresenceTracker.start_link()
    context
  end
end
