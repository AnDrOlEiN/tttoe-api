defmodule Tictactoe.Game.State.JoinedPlayers do
  defstruct players: MapSet.new()
  require Logger
  def none, do: %__MODULE__{}

  def add_player(%__MODULE__{} = joined_players, nickname \\ "lazy_vitalya", sign \\ "X") do
    if full?(joined_players) do
      {:error, :game_full}
    else
      sign_to_add = check_sign(joined_players.players, sign)
      new_player = MapSet.put(joined_players.players, %{sign_to_add => nickname})

      {:ok, sign_to_add, %{joined_players | players: new_player}}
    end
  end

  def remove_player(joined_players, player_map) do
    with :ok <- verify_player_joined(joined_players, player_map) do
      {:ok, %{joined_players | players: MapSet.delete(joined_players.players, player_map)}}
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

  def select_player_randomly() do
    case Enum.random(0..1) do
      1 -> "X"
      0 -> "O"
    end
  end

  defp check_sign(players, sign) do
    case sign do
      n when n in ["X", "O"] ->
        if MapSet.size(players) == 0, do: sign

        if Enum.any?(players, fn player -> Map.has_key?(player, sign) end),
          do: get_opposite_of_sign(sign),
          else: sign

      _ ->
        if MapSet.size(players) == 0 do
          "X"
        else
          players
          |> MapSet.to_list()
          |> List.first()
          |> Map.keys()
          |> List.first()
          |> case do
            "X" -> "O"
            "O" -> "X"
            _ -> "X"
          end
        end
    end
  end

  defp get_opposite_of_sign(sign) do
    case sign do
      "X" -> "O"
      "O" -> "X"
    end
  end


  defp full?(%__MODULE__{players: players}) do
    MapSet.size(players) == 2
  end

  defp verify_player_joined(%__MODULE__{players: players}, player_map) do
    if MapSet.member?(players, player_map) do
      :ok
    else
      {:error, :player_not_joined}
    end
  end
end
