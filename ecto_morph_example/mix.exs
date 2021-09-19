defmodule EctoMorphExample.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecto_morph_example,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {EctoMorphExample.Application, []}
    ]
  end

  defp deps do
    [
      {:ecto_morph, path: "../"}
    ]
  end
end
