defmodule Tictactoe.Game.State.JoinedPlayers do
  defstruct players: MapSet.new()

  def none, do: %__MODULE__{}

  def add_player(%__MODULE__{} = joined_players) do
    if full?(joined_players) do
      {:error, :game_full}
    else
      to_add = player_to_add(joined_players.players)
      new_players = MapSet.put(joined_players.players, to_add)

      {:ok, to_add, %{joined_players | players: new_players}}
    end
  end

  def remove_player(joined_players, player_sign) do
    with :ok <- verify_player_joined(joined_players, player_sign) do
      {:ok, %{joined_players | players: MapSet.delete(joined_players.players, player_sign)}}
    end
  end

  def verify_complete(%__MODULE__{} = joined_players) do
    if full?(joined_players) do
      :ok
    else
      {:error, :game_not_full}
    end
  end

  def empty?(%__MODULE__{} = joined_players) do
    joined_players == none()
  end

  defp player_to_add(players) do
    if not MapSet.member?(players, "X") do
      "X"
    else
      "O"
    end
  end

  defp full?(%__MODULE__{players: players}) do
    MapSet.size(players) == 2
  end

  defp verify_player_joined(%__MODULE__{players: players}, player_sign) do
    if MapSet.member?(players, player_sign) do
      :ok
    else
      {:error, :player_not_joined}
    end
  end
end
