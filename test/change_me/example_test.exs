defmodule ChangeMe.ExampleTest do
  use ExUnit.Case

  setup do
    require ChangeMe
    schema  = %{
      "type" => "object",
      "properties" => %{
        "foo" => %{
          "type" => "string"
        }
      }
    } |> ExJsonSchema.Schema.resolve()

    _return_value = ChangeMe.define_ecto_schema_from_json(Foo, schema)

    :ok
  end

  test "casts valid data" do
    example = %ChangeMe.Example{}

    changeset = ChangeMe.Example.changeset(example, %{"foo" => %{"foo" => "bar"}})

    assert changeset.valid?

    struct = Ecto.Changeset.apply_changes(changeset)

    assert struct == %ChangeMe.Example{foo: %{foo: "bar"}, id: nil}
  end

  test "adds errors for invalid data" do
    example = %ChangeMe.Example{}

    changeset = ChangeMe.Example.changeset(example, %{"foo" => %{"foo" => 1}})

    refute changeset.valid?

    assert changeset.errors == [
             foo: {"Type mismatch. Expected String but got Integer. #/foo", []}
           ]
  end
end
