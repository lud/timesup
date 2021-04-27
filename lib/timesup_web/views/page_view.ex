defmodule TimesupWeb.PageView do
  use TimesupWeb, :view
  alias Timesup.Game

  def game_summary(%Game{} = game) do
    game.teams
    |> Enum.with_index()
    |> Enum.map(fn {_, index} -> team_summary(game, index) end)
    |> Enum.sort_by(& &1.total, :desc)
  end

  def team_summary(game, i) do
    %{
      index: i,
      number: i + 1,
      players: Game.team(game, i),
      points: Game.team_points(game, i),
      total: Game.team_points(game, i) |> Map.values() |> Enum.sum()
    }
  end

  @name_1 "Les eFentastic"
  @name_2 "Les MerveillouseFen"

  def team_name(0) do
    "Équipe 1 : #{@name_1}"
  end

  def team_name(1) do
    "Équipe 2 : #{@name_2}"
  end

  def team_name(team_index) do
    "Équipe " <> to_string(team_index + 1)
  end

  def team_name_alt(0) do
    "1 : #{@name_1}"
  end

  def team_name_alt(1) do
    "2 : #{@name_2}"
  end

  def team_name_alt(team_index) do
    "#{team_index + 1}"
  end
end
