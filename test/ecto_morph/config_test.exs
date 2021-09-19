defmodule EctoMorph.ConfigTest do
  use ExUnit.Case

  describe "json_schemas_path/0" do
    setup do
      json_schemas_path =
        Application.get_env(
          :ecto_morph,
          :json_schemas_path,
          :not_present
        )

      ## Clean up
      if json_schemas_path == :not_present do
        on_exit(fn ->
          Application.delete_env(:ecto_morph, :json_schemas_path)
        end)
      else
        on_exit(fn ->
          Application.put_env(
            :ecto_morph,
            :json_schemas_path,
            json_schemas_path
          )
        end)
      end

      :ok
    end

    test "returns default_json_schemas_path when not configured" do
      ## Test Setup
      Application.delete_env(:ecto_morph, :json_schemas_path)

      ## Kick-off
      json_schemas_path = EctoMorph.Config.json_schemas_path()

      expected_json_schemas_path = "priv/ecto_morph"

      assert json_schemas_path == expected_json_schemas_path
    end

    test "returns configured json_schemas_path when configured" do
      configured_schema_path = "some/schema/path"

      ## Test Setup
      Application.put_env(
        :ecto_morph,
        :json_schemas_path,
        configured_schema_path
      )

      ## Kick-off
      json_schemas_path = EctoMorph.Config.json_schemas_path()

      assert json_schemas_path == configured_schema_path
    end
  end
end
