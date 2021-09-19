defmodule EctoMorph.FileUtils do
  @moduledoc """
  File/Dir helper functions for EctoMorph
  """

  @doc """
  Recursively prints all the files in a given directory
  """
  def ls_r!(path \\ ".") do
    cond do
      File.regular?(path) ->
        [path]

      File.dir?(path) ->
        path
        |> File.ls!()
        |> Enum.map(&Path.join(path, &1))
        |> Enum.map(&ls_r!/1)
        |> Enum.concat()

      true ->
        []
    end
  end
end
