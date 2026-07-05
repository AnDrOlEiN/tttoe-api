defmodule TictactoeWeb.PageControllerTest do
  use TictactoeWeb.ConnCase

  test "GET / redirects to the static index page", %{conn: conn} do
    conn = get(conn, "/")
    assert redirected_to(conn) == "/html/index.html"
  end
end
