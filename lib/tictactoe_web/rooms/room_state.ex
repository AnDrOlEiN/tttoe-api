defmodule TictactoeWeb.Room.State do
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def put(key, value) do
    Agent.update(__MODULE__, & [%{"id" => key, "name" => value} | &1])
  end

  def list() do
    Agent.get(__MODULE__, & &1)
  end

  def get(key) do
    Agent.get(__MODULE__, & &1 |> Enum.filter(fn value -> Map.get(value, "id") == key end) |> List.first())
  end

  def delete(key) do
    Agent.update(__MODULE__, &Enum.filter(&1, fn value -> Map.get(value, "id") != key end))
  end
end
