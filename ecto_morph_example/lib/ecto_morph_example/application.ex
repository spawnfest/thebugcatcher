defmodule EctoMorphExample.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # This can be hooked up with a watcher that looks for changes
    # Loads and defines Ecto schemas using EctoMorph
    initialize_ecto_repos()

    children = [
      # Starts a worker by calling: EctoMorphExample.Worker.start_link(arg)
      # {EctoMorphExample.Worker, arg}
    ]

    opts = [strategy: :one_for_one, name: EctoMorphExample.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp initialize_ecto_repos do
    # Can be moved to Supervisor children
    EctoMorph.start_link()
    EctoMorph.load_json_schemas!()
  end
end
