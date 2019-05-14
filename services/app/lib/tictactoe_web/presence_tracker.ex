defmodule TictactoeWeb.PresenceTracker do
  @behaviour Phoenix.Tracker
  require Logger

  alias Tictactoe.{GameSupervisor, GameServer}
  alias TictactoeWeb.GameChannel

  def start_link() do
    opts = [
      name: __MODULE__,
      pubsub_server: Tictactoe.PubSub
    ]

    GenServer.start_link(Phoenix.Tracker, [__MODULE__, opts, opts], opts)
  end

  def init(opts) do
    server = Keyword.fetch!(opts, :pubsub_server)
    {:ok, %{pubsub_server: server, node_name: Phoenix.PubSub.node_name(server)}}
  end

  def track_player(socket, player_sign) do
    Phoenix.Tracker.track(__MODULE__, socket.channel_pid, socket.topic, player_sign, %{})
  end

  def handle_diff(%{} = topic_diffs, state) do
    topic_diffs
    |> Enum.each(fn {topic_name, {_joins, leaves}} ->
      Enum.each(leaves, fn {player_sign, _meta} ->
        handle_leave(topic_name, player_sign)
      end)
    end)

    {:ok, state}
  end

  defp handle_leave("game:" <> game_id = topic_name, player_sign) do
    Logger.info("Player #{inspect(player_sign)} left from game #{game_id}")

    game_pid = GameSupervisor.find_or_start_game(game_id)
    GameServer.remove_player(game_pid, player_sign)
    TictactoeWeb.Room.Controller.remove_due_leave(game_id)

    with :stopped <- GameServer.stop_if_empty(game_pid) do
      :ok
    else
      _ ->
        GameChannel.broadcast_left_player(topic_name)
    end
  end
end
