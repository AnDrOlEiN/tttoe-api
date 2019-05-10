defmodule TictactoeWeb.Router do
  use TictactoeWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/room", TictactoeWeb do
    pipe_through(:api)
    get("/", Room.Controller, :list)
    post("/", Room.Controller, :create)
    get("/:id", Room.Controller, :read)
    delete("/:id", Room.Controller, :remove)
  end
end
