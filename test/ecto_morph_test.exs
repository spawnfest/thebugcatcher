defmodule EctoMorphTest do
  use ExUnit.Case, async: false

  describe "validate/2" do
  end

  describe "load_json_schemas!/0" do
    setup tags do
      new_path = Map.fetch!(tags, :path)

      old_path = EctoMorph.Config.json_schemas_path()

      Application.put_env(
        :ecto_morph,
        :json_schemas_path,
        new_path
      )

      on_exit(fn ->
        Application.put_env(
          :ecto_morph,
          :json_schemas_path,
          old_path
        )
      end)
    end

    @tag path: "./test/support/json_schemas"
    test "loads json schemas from the config layer when valid json_schemas" do
      assert length(EctoMorph.get_all_modules()) == 0

      EctoMorph.load_json_schemas!()

      defined_module_names = EctoMorph.get_all_modules()

      assert Enum.count(defined_module_names) > 0

      Enum.each(defined_module_names, fn defined_module_name ->
        defined_module = :"#{defined_module_name}"

        assert Code.ensure_loaded?(defined_module)

        defined_functions = defined_module.__info__(:functions)

        assert {:__schema__, 1} in defined_functions

        assert {:changeset, 2} in defined_functions
      end)

      datetime_schema = EctoMorph.get_module_for_id("datetime_schema")
      datetime_schema = :"#{datetime_schema}"
      assert datetime_schema.__schema__(:type, :occured_at) == :utc_datetime

      on_exit(fn ->
        Enum.each(defined_module_names, fn defined_module_name ->
          defined_module = :"#{defined_module_name}"

          :code.delete(defined_module)
          :code.purge(defined_module)

          refute Code.ensure_loaded?(defined_module)
        end)

        Agent.update(EctoMorph, fn _ -> [] end)
      end)
    end

    @tag path: "./test/support/ajsdnoasubdosand_bad_path"
    test "raises error when invalid path" do
      assert length(EctoMorph.get_all_modules()) == 0

      EctoMorph.load_json_schemas!()

      assert length(EctoMorph.get_all_modules()) == 0
    end

    @tag path: "./test/support/invalid_json_schemas"
    test "raises error when invalid schema" do
    end
  end

  describe "module_from_schema/0" do
    setup do
      on_exit(fn ->
        Agent.update(EctoMorph, fn _ -> [] end)
      end)
    end

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

  describe "schemaless_changeset/3" do
    setup do
      schema = %{
        "type" => "object",
        "properties" => %{
          "foo" => %{
            "type" => "string"
          },
          "occurred_at" => %{
            "type" => "string",
            "format" => "date-time"
          },
          # "child" => %{
          #   "type" => "object",
          #   "properties" => %{
          #     "name" => %{
          #       "type" => "string"
          #     }
          #   }
          # }
        }
      }
      |> ExJsonSchema.Schema.resolve()

      %{schema: schema}
    end

    test "valid attrs", %{schema: schema} do
      data = %{}

      occurred_at = DateTime.utc_now() |> DateTime.truncate(:second)

      params = %{
        foo: "bar",
        occurred_at: occurred_at |> DateTime.to_iso8601(),
        child: %{
          name: "bob"
        }
      }

      changeset = EctoMorph.schemaless_changeset(data, schema, params)

      assert changeset.valid?

      struct = Ecto.Changeset.apply_changes(changeset)

      assert struct == %{
        foo: "bar",
        occurred_at: occurred_at,
        child: %{
          name: "bob"
        }
      }
    end

    test "invalid attrs", %{schema: schema} do
      data = %{}
      params = %{
        foo: 1,
        occurred_at: 1,
        child: %{
          name: 1
        }
      }

      changeset = EctoMorph.schemaless_changeset(data, schema, params)

      refute changeset.valid?

      # assert Ecto.Changeset.traverse_errors(changeset, & &1) == %{
      #          foo: [{"Type mismatch. Expected String but got Integer.", []}],
      #          occurred_at: [{"Expected to be a valid ISO 8601 date-time.", []}]
      #        }

     assert Ecto.Changeset.traverse_errors(changeset, & &1) == %{
       foo: [{"is invalid", [type: :string, validation: :cast]}],
       occurred_at: [{"is invalid", [type: :utc_datetime, validation: :cast]}]
     }
    end
  end
end
