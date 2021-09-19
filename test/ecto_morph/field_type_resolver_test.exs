defmodule EctoMorph.FieldTypeResolverTest do
  use ExUnit.Case, async: false

  alias EctoMorph.FieldTypeResolver

  describe "run/1" do
    test "returns :boolean when given type \"boolean\"" do
      assert :boolean == FieldTypeResolver.run("boolean")
    end

    test "returns :decimal when given type \"number\"" do
      assert :decimal == FieldTypeResolver.run("number")
    end

    test "returns :integer when given type \"integer\"" do
      assert :integer == FieldTypeResolver.run("integer")
    end

    test "returns :string when given type \"string\"" do
      assert :string == FieldTypeResolver.run("string")
    end

    test "returns :datetime when given type \"string\" and format \"date-time\"" do
      assert :utc_datetime == FieldTypeResolver.run("string", "date-time")
    end

    test "raises an error if provided with an unsupported type value" do
      assert_raise RuntimeError, fn ->
        FieldTypeResolver.run("iamtotallynotsupported")
      end
    end
  end
end
