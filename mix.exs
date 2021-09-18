defmodule EctoMorph.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecto_morph,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_json_schema, "~> 0.9.0"},
      {:ecto, "~> 3.0"},
    ]
  end
end
