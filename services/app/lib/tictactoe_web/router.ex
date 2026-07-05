defmodule TictactoeWeb.Router do
  use TictactoeWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", TictactoeWeb do
    get("/", Static.Controller, :index)
  end

  scope "/room", TictactoeWeb do
    pipe_through(:api)
    get("/", RoomController, :list)
    post("/", RoomController, :create)
    get("/:id", RoomController, :read)
    delete("/:id", RoomController, :remove)
  end
end
