defmodule TictactoeWeb.RoomController do
  use TictactoeWeb, :controller

  alias Tictactoe.Rooms

  def list(conn, _params) do
    json(conn, %{data: Rooms.list()})
  end

  def create(conn, %{"name" => name}) do
    uuid = UUID.uuid1()
    Rooms.put(uuid, name)
    json(conn, %{name: name, id: uuid})
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "name is required"})
  end

  def read(conn, params) do
    %{"id" => id} = params
    name = Rooms.get(id)
    json(conn, %{data: name})
  end

  def remove(conn, params) do
    %{"id" => id} = params
    Rooms.delete(id)
    json(conn, %{id: id})
  end
end
