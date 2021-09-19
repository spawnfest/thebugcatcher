defmodule EctoMorph.Config do
  @moduledoc """
  Config helpers for EctoMorph
  """
  @default_json_schemas_path "priv/ecto_morph"

  def json_schemas_path do
    Application.get_env(
      :ecto_morph,
      :json_schemas_path,
      @default_json_schemas_path
    )
  end
end
