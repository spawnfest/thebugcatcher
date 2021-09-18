defmodule EctoMorphTest do
  use ExUnit.Case

  describe "validate/2" do
  end

  describe "load_json_schemas!/0" do
    setup tags do
      new_path = Map.fetch!(tags, :path)

      old_path = EctoMorph.Config.json_schemas_path()

      on_exit(fn ->
        Application.put_env(
          :ecto_morph,
          :json_schemas_path,
          old_path
        )
      end)

      Application.put_env(
        :ecto_morph,
        :json_schemas_path,
        new_path
      )

      :ok
    end

    @tag path: "./test/support/json_schemas"
    test "loads json schemas from the config layer when valid json_schemas" do
      assert length(EctoMorph.get_all_modules()) == 0

      EctoMorph.load_json_schemas!()

      [defined_module_name] = EctoMorph.get_all_modules()

      defined_module = :"#{defined_module_name}"

      assert Code.ensure_loaded?(defined_module)

      defined_functions = defined_module.__info__(:functions)

      assert {:__schema__, 1} in defined_functions

      assert {:changeset, 2} in defined_functions

      on_exit(fn ->
        :code.delete(defined_module)
        :code.purge(defined_module)

        refute Code.ensure_loaded?(defined_module)

        Agent.update(EctoMorph, fn _ -> [] end)
      end)
    end

    @tag path: "./test/support/ajsdnoasubdosand_bad_path"
    test "raises error when invalid path" do
    end

    @tag path: "./test/support/invalid_json_schemas"
    test "raises error when invalid schema" do
    end
  end

  describe "module_from_schema/0" do
    test "returns a stringified module name for an resolved_schema" do
      resolved_schema =
        %{
          "type" => "object",
          "properties" => %{
            "foo" => %{
              "type" => "string"
            }
          }
        }
        |> ExJsonSchema.Schema.resolve()

      schema_name = EctoMorph.module_from_schema(resolved_schema)

      assert schema_name =~ "Schema.ID"
    end
  end
end
