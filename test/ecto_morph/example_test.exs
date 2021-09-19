defmodule EctoMorph.ExampleTest do
  use ExUnit.Case

  setup do
    require EctoMorph

    # TODO?
    # customer_json_schema = """
    #   {
    #     "$id": "https://example.com/schemas/customer",
    #     "type": "object",
    #     "properties": {
    #       "first_name": { "$ref": "#/$defs/name" },
    #       "last_name": { "$ref": "#/$defs/name" },
    #       "shipping_address": { "$ref": "/schemas/address" },
    #       "billing_address": { "$ref": "/schemas/address" }
    #     },
    #     "required": ["first_name", "last_name", "shipping_address", "billing_address"],
    #     "$defs": {
    #       "name": { "type": "string" }
    #     }
    #   }
    # """
    # |> Jason.decode!()
    # |> ExJsonSchema.Schema.resolve()

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
            },
            "required" => ["name"]
          },
          "name" => %{
            "$ref" => "#/$defs/name"
          },
          "car" => %{
            "$ref" => "#/$defs/car"
          }
        },
        "$defs" => %{
          "name" => %{
            "type" => "string"
          },
          "car" => %{
            "type" => "object",
            "properties" => %{
              "color" => %{
                "type" => "string"
              }
            }
          }
        }
      }
      |> ExJsonSchema.Schema.resolve()

    require IEx
    IEx.pry()

    IO.inspect(schema, label: "AWESOME")
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
          },
          "name" => "Adi",
          "car" => %{
            "color" => "blue"
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
               },
               name: "Adi",
               car: %{
                 __struct__: Foo.Car,
                 color: "blue",
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

    assert Ecto.Changeset.traverse_errors(changeset, & &1) ==
             %{
               foo: %{
                 child: %{
                   name: [
                     {"is invalid", [{:type, :string}, {:validation, :cast}]}
                   ]
                 },
                 foo: [
                   {"is invalid", [{:type, :string}, {:validation, :cast}]}
                 ],
                 occurred_at: [
                   {
                     "is invalid",
                     [{:type, :utc_datetime}, {:validation, :cast}]
                   }
                 ]
               }
             }
  end

  test "adds errors for invalid data (ex_json_schema)" do
    example = %EctoMorph.Example{}

    occurred_at = DateTime.utc_now() |> DateTime.truncate(:second)

    changeset =
      EctoMorph.Example.changeset(example, %{
        "foo" => %{
          "foo" => "bar",
          "occurred_at" => occurred_at |> DateTime.to_iso8601(),
          "child" => %{}
        }
      })

    refute changeset.valid?

    assert Ecto.Changeset.traverse_errors(changeset, & &1) ==
             %{foo: %{child: [{"Required property name was not present.", []}]}}
  end
end
