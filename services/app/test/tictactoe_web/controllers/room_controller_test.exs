defmodule TictactoeWeb.RoomControllerTest do
  use TictactoeWeb.ConnCase

  test "POST /room creates a room and lists it", %{conn: conn} do
    conn = post(conn, "/room", %{"name" => "created room"})
    assert %{"name" => "created room", "id" => id} = json_response(conn, 200)

    list_conn = get(build_conn(), "/room")
    assert %{"data" => rooms} = json_response(list_conn, 200)
    assert %{"id" => id, "name" => "created room"} in rooms
  end

  test "POST /room without a name returns 400", %{conn: conn} do
    conn = post(conn, "/room", %{})
    assert json_response(conn, 400) == %{"error" => "name is required"}
  end

  test "GET /room/:id returns the room", %{conn: conn} do
    %{"id" => id} = json_response(post(conn, "/room", %{"name" => "readable"}), 200)

    conn = get(build_conn(), "/room/#{id}")
    assert %{"data" => %{"id" => ^id, "name" => "readable"}} = json_response(conn, 200)
  end

  test "GET /room/:id returns null data for unknown ids", %{conn: conn} do
    conn = get(conn, "/room/unknown-id")
    assert json_response(conn, 200) == %{"data" => nil}
  end

  test "DELETE /room/:id removes the room", %{conn: conn} do
    %{"id" => id} = json_response(post(conn, "/room", %{"name" => "doomed"}), 200)

    delete_conn = delete(build_conn(), "/room/#{id}")
    assert json_response(delete_conn, 200) == %{"id" => id}

    read_conn = get(build_conn(), "/room/#{id}")
    assert json_response(read_conn, 200) == %{"data" => nil}
  end
end
