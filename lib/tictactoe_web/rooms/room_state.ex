defmodule TictactoeWeb.Room.State do
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def put(key, value) do
    Agent.update(__MODULE__, &Map.put(&1, key, value))
  end

  def list() do
    Agent.get(__MODULE__, & &1)
  end

  def get(key) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  end

  def delete(key) do
    Agent.update(__MODULE__, &Map.delete(&1, key))
  end
end
