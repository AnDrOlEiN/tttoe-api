defmodule Tictactoe.RoomsTest do
  # Rooms is a globally named process started by the application,
  # so these tests must not run concurrently with each other.
  use ExUnit.Case

  alias Tictactoe.{Rooms, GameSupervisor}

  test "stores and lists rooms" do
    :ok = Rooms.put("rooms-test-basic", "basic room")

    assert %{"id" => "rooms-test-basic", "name" => "basic room"} in Rooms.list()
    assert Rooms.get("rooms-test-basic") == %{"id" => "rooms-test-basic", "name" => "basic room"}

    :ok = Rooms.delete("rooms-test-basic")
    assert Rooms.get("rooms-test-basic") == nil
  end

  test "the sweep reaps expired rooms that never got a game" do
    :ok = Rooms.put("rooms-test-stale", "never joined")

    expire_and_sweep()

    assert Rooms.get("rooms-test-stale") == nil
  end

  test "the sweep keeps fresh rooms" do
    :ok = Rooms.put("rooms-test-fresh", "just created")

    sweep()

    assert Rooms.get("rooms-test-fresh") != nil

    Rooms.delete("rooms-test-fresh")
  end

  test "the sweep keeps expired rooms whose game is running" do
    start_supervised!(%{id: GameSupervisor, start: {GameSupervisor, :start_link, []}})
    GameSupervisor.find_or_start_game("rooms-test-active")

    :ok = Rooms.put("rooms-test-active", "game in progress")

    expire_and_sweep()

    assert Rooms.get("rooms-test-active") != nil

    Rooms.delete("rooms-test-active")
  end

  defp expire_and_sweep() do
    ttl = Application.get_env(:tictactoe, :room_ttl)
    Process.sleep(ttl + 10)
    sweep()
  end

  defp sweep() do
    send(Process.whereis(Rooms), :sweep)
    # Any call is handled after the already-queued :sweep message,
    # so this blocks until the sweep has run.
    Rooms.list()
  end
end
