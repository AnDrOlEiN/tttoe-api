defmodule Tictactoe.GameSupervisor do
  use DynamicSupervisor

  alias Tictactoe.GameServer

  def start_link() do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def find_or_start_game(game_id) do
    game_id
    |> start_game
    |> case do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  def start_game(game_name) do
    spec = Supervisor.Spec.worker(GameServer, [game_name])
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_game(game) do
    DynamicSupervisor.terminate_child(__MODULE__, game)
  end
end
