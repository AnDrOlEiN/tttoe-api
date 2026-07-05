defmodule Tictactoe.Rooms do
  @moduledoc """
  In-memory room registry. Rooms whose game emptied are deleted by the
  presence tracker; rooms that never got a game are reaped by a periodic
  sweep once their TTL expires.
  """

  use GenServer

  alias Tictactoe.GameSupervisor

  @sweep_interval :timer.minutes(5)
  @default_ttl :timer.hours(1)

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def put(key, value) do
    GenServer.call(__MODULE__, {:put, key, value})
  end

  def list() do
    GenServer.call(__MODULE__, :list)
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def delete(key) do
    GenServer.call(__MODULE__, {:delete, key})
  end

  def init(rooms) do
    schedule_sweep()
    {:ok, rooms}
  end

  def handle_call({:put, key, value}, _from, rooms) do
    entry = %{room: %{"id" => key, "name" => value}, inserted_at: now()}
    {:reply, :ok, [entry | rooms]}
  end

  def handle_call(:list, _from, rooms) do
    {:reply, Enum.map(rooms, & &1.room), rooms}
  end

  def handle_call({:get, key}, _from, rooms) do
    room =
      rooms
      |> Enum.find(fn %{room: room} -> room["id"] == key end)
      |> case do
        nil -> nil
        entry -> entry.room
      end

    {:reply, room, rooms}
  end

  def handle_call({:delete, key}, _from, rooms) do
    {:reply, :ok, Enum.reject(rooms, fn %{room: room} -> room["id"] == key end)}
  end

  def handle_info(:sweep, rooms) do
    schedule_sweep()
    {:noreply, Enum.reject(rooms, &expired_without_game?/1)}
  end

  defp expired_without_game?(%{room: %{"id" => id}, inserted_at: inserted_at}) do
    now() - inserted_at > ttl() and GameSupervisor.whereis_game(id) == nil
  end

  defp schedule_sweep() do
    Process.send_after(self(), :sweep, @sweep_interval)
  end

  defp now(), do: System.monotonic_time(:millisecond)

  defp ttl(), do: Application.get_env(:tictactoe, :room_ttl, @default_ttl)
end
