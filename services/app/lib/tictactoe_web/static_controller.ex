defmodule TictactoeWeb.Static.Controller do
  use TictactoeWeb, :controller

  def index(conn, _params) do
    redirect(conn, to: "/html/index.html")
  end
end
