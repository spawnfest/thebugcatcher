defmodule EctoMorph.ExampleTest do
  use ExUnit.Case

  setup do
    require EctoMorph

    schema =
      %{
        "type" => "object",
        "properties" => %{
          "foo" => %{
            "type" => "string"
          }
        }
      }
      |> ExJsonSchema.Schema.resolve()

    _return_value = EctoMorph.define_ecto_schema_from_json(Foo, schema)

    :ok
  end

  test "casts valid data" do
    example = %EctoMorph.Example{}

    changeset = EctoMorph.Example.changeset(example, %{"foo" => %{"foo" => "bar"}})

    assert changeset.valid?

    struct = Ecto.Changeset.apply_changes(changeset)

    assert struct == %EctoMorph.Example{foo: %{__struct__: Foo, foo: "bar"}, id: nil}
  end

  test "adds errors for invalid data" do
    example = %EctoMorph.Example{}

    changeset = EctoMorph.Example.changeset(example, %{"foo" => %{"foo" => 1}})

    refute changeset.valid?

    assert Ecto.Changeset.traverse_errors(changeset, & &1) == %{
             foo: %{
               foo: [{"Type mismatch. Expected String but got Integer.", []}]
             }
           }
  end
end
