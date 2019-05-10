defmodule TictactoeWeb.Room.Controller do
  use TictactoeWeb, :controller

  def list(conn, _params) do
    json(conn, %{data: TictactoeWeb.Room.State.list()})
  end

  def create(conn, params) do
    %{"name" => name} = params
    uuid = UUID.uuid1()
    TictactoeWeb.Room.State.put(uuid, name)
    json(conn, %{data: "created room with name \"#{name}\" and id \"#{uuid}\""})
  end

  def read(conn, params) do
    %{"id" => id} = params
    name = TictactoeWeb.Room.State.get(id)
    json(conn, %{data: name})
  end

  def remove(conn, params) do
    %{"id" => id} = params
    TictactoeWeb.Room.State.delete(id)
    json(conn, %{data: "removed room with id \"#{id}\""})
  end
end
