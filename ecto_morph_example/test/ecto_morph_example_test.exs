defmodule EctoMorphExampleTest do
  use ExUnit.Case

  describe "schemas" do
    test "loads schemas using ecto_morph" do
      schema_modules = EctoMorph.get_all_modules()
      assert length(schema_modules) == 2

      [complex_schema_name, simple_schema_name] = schema_modules

      simple_schema = :"#{simple_schema_name}"
      complex_schema = :"#{complex_schema_name}"

      assert simple_schema.__schema__(:fields) == [:id, :foo]

      assert complex_schema.__schema__(:fields) == [:id, :occurred_at]
    end
  end
end
