defmodule Tictactoe.Application do
  use Application

  import Supervisor.Spec

  @environment Mix.env()
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    # Define workers and child supervisors to be supervised
    children =
      game_supervisor() ++
        [
          supervisor(TictactoeWeb.Endpoint, [])
        ] ++ presence_tracker() ++ [TictactoeWeb.Room.State]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tictactoe.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    TictactoeWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp game_supervisor() do
    if @environment == :test do
      []
    else
      [supervisor(Tictactoe.GameSupervisor, [])]
    end
  end

  defp presence_tracker() do
    if @environment == :test do
      []
    else
      [supervisor(TictactoeWeb.PresenceTracker, [])]
    end
  end
end
