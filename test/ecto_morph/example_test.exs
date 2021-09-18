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
          },
          "occurred_at" => %{
            "type" => "string",
            "format" => "date-time"
          },
          "child" => %{
            "type" => "object",
            "properties" => %{
              "name" => %{
                "type" => "string"
              }
            }
          }
        }
      }
      |> ExJsonSchema.Schema.resolve()

    _return_value = EctoMorph.define_ecto_schema_from_json(Foo, schema)

    :ok
  end

  test "casts valid data" do
    example = %EctoMorph.Example{}

    occurred_at = DateTime.utc_now() |> DateTime.truncate(:second)

    changeset =
      EctoMorph.Example.changeset(example, %{
        "foo" => %{
          "foo" => "bar",
          "occurred_at" => occurred_at |> DateTime.to_iso8601(),
          "child" => %{
            "name" => "bob"
          }
        }
      })

    assert changeset.valid?

    struct = Ecto.Changeset.apply_changes(changeset)

    assert struct == %EctoMorph.Example{
             foo: %{
               __struct__: Foo,
               foo: "bar",
               occurred_at: occurred_at,
               child: %{
                 __struct__: Foo.Child,
                 name: "bob",
                 id: nil
               }
             },
             id: nil
           }
  end

  test "adds errors for invalid data" do
    example = %EctoMorph.Example{}

    changeset =
      EctoMorph.Example.changeset(example, %{
        "foo" => %{"foo" => 1, "occurred_at" => "X", "child" => %{"name" => 1}}
      })

    refute changeset.valid?

    assert Ecto.Changeset.traverse_errors(changeset, & &1) == %{
             foo: %{
               foo: [{"Type mismatch. Expected String but got Integer.", []}],
               occurred_at: [{"Expected to be a valid ISO 8601 date-time.", []}]
             }
           }
  end
end
