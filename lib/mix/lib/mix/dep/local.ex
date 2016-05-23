# This module keeps a local dependency git repo configuration up to date.
# The localfile keeps the latest local dependency information that is used
# whenever a dependency is affected via any of the deps.local* tasks.
defmodule Mix.Dep.Local do
  @moduledoc false

  @doc """
  Reads the localfile, returns a map containing
  each app name and its current local dep information.
  """
  @spec read() :: map
  def read() do
    case File.read(localfile) do
      {:ok, info} ->
        assert_no_merge_conflicts_in_localfile(localfile, info)
        case Code.eval_string(info, [], file: localfile) do
          {local, _binding} when is_map(local)  -> local
          {_, _binding} -> %{}
        end
      {:error, _} ->
        %{}
    end
  end

  @doc """
  Receives a map and writes it as the current local dep configuration.
  """
  @spec write(map) :: :ok
  def write(map) do
    unless map == read do
      lines =
        for {app, rev} <- Enum.sort(map), rev != nil do
          ~s("#{app}": #{inspect rev, limit: :infinity})
        end
      File.write! localfile, "%{" <> Enum.join(lines, ",\n  ") <> "}\n"
    end
    :ok
  end

  defp localfile do
    Mix.Project.config[:localfile]
  end

  defp assert_no_merge_conflicts_in_localfile(localfile, info) do
    if String.contains?(info, ~w(<<<<<<< ======= >>>>>>>)) do
      Mix.raise "Your #{localfile} contains merge conflicts. Please resolve the conflicts " <>
                "and run the command again"
    end
  end
end
