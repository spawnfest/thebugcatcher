defmodule EctoMorph.Schema.DefinerTest do
  use ExUnit.Case

  alias EctoMorph.Schema.Definer

  describe "define_ecto_schema_from_json/2" do
    setup do
      require EctoMorph.Schema.Definer

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
            "names" => %{
              "type" => "array",
              "items" => %{
                "$ref" => "#/$defs/name"
              }
            },
            "car" => %{
              "$ref" => "#/$defs/car"
            },
            "cars" => %{
              "type" => "array",
              "items" => %{
                "$ref" => "#/$defs/car"
              }
            },
            "bars" => %{
              "type" => "array",
              "items" => %{
                "type" => "object",
                "properties" => %{
                  "name" => %{
                    "type" => "string"
                  }
                }
              }
            },
            "tags" => %{
              "type" => "array",
              "items" => %{
                "type" => "string"
              }
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
              },
              "required" => ["color"]
            }
          }
        }
        |> ExJsonSchema.Schema.resolve()

      {:module, Foo, _, _} = Definer.define_ecto_schema_from_json(Foo, schema)

      :ok
    end

    test "casts valid data" do
      occurred_at = DateTime.utc_now() |> DateTime.truncate(:second)

      foo_params = %{
        "foo" => "bar",
        "occurred_at" => occurred_at |> DateTime.to_iso8601(),
        "child" => %{
          "name" => "bob"
        },
        "name" => "Adi",
        "names" => ["Josh", "Eric"],
        "car" => %{
          "color" => "blue"
        },
        "cars" => [
          %{
            "color" => "red"
          }
        ],
        "bars" => [
          %{"name" => "barname"},
          %{"name" => "wildrover"}
        ],
        "tags" => [
          "cool",
          "sometimes"
        ]
      }

      # Needs to be dynamic to avoid warnings
      changeset = apply(Foo, :changeset, [%{__struct__: Foo}, foo_params])

      assert changeset.valid?

      struct = Ecto.Changeset.apply_changes(changeset)

      assert struct == %{
               __struct__: Foo,
               foo: "bar",
               occurred_at: occurred_at,
               child: %{
                 __struct__: Foo.Child,
                 name: "bob",
                 id: nil
               },
               name: "Adi",
               names: ["Josh", "Eric"],
               car: %{
                 __struct__: Foo.Car,
                 color: "blue",
                 id: nil
               },
               cars: [
                 %{
                   __struct__: Foo.Cars,
                   color: "red",
                   id: nil
                 }
               ],
               bars: [
                 %{
                   __struct__: Foo.Bars,
                   id: nil,
                   name: "barname"
                 },
                 %{
                   __struct__: Foo.Bars,
                   id: nil,
                   name: "wildrover"
                 }
               ],
               tags: [
                 "cool",
                 "sometimes"
               ]
             }
    end
  end
end
