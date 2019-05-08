defmodule TictactoeWeb.Router do
  use TictactoeWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", TictactoeWeb do
    pipe_through :api
  end
end
