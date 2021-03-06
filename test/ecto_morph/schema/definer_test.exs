defmodule EctoMorph.Schema.DefinerTest do
  use ExUnit.Case

  alias EctoMorph.Schema.Definer

  setup_all do
    require EctoMorph.Schema.Definer

    schema =
      %{
        "type" => "object",
        "properties" => %{
          "title" => %{
            "type" => "string"
          },
          "occurred_at" => %{
            "type" => "string",
            "format" => "date-time"
          },
          "likes_to_eat_potato" => %{
            "type" => "boolean"
          },
          "favorite_number" => %{
            "type" => "number"
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
          },
          "truck" => %{
            "type" => "object",
            "properties" => %{
              "color" => %{
                "type" => "string"
              },
              "size" => %{
                "type" => "integer"
              }
            },
            "required" => ["color", "size"]
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

  describe "define_ecto_schema_from_json/2" do
    test "casts valid data" do
      occurred_at = DateTime.utc_now() |> DateTime.truncate(:second)

      foo_params = %{
        "title" => "bar",
        "occurred_at" => occurred_at |> DateTime.to_iso8601(),
        "likes_to_eat_potato" => true,
        "favorite_number" => 5.0,
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
        ],
        "truck" => %{
          "color" => "yellow",
          "size" => 1
        }
      }

      # Needs to be dynamic to avoid warnings
      changeset = apply(Foo, :changeset, [%{__struct__: Foo}, foo_params])

      assert changeset.valid?

      struct = Ecto.Changeset.apply_changes(changeset)

      assert struct == %{
               __struct__: Foo,
               title: "bar",
               occurred_at: occurred_at,
               likes_to_eat_potato: true,
               favorite_number: Decimal.new("5.0"),
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
               ],
               truck: %{
                 __struct__: Foo.Truck,
                 id: nil,
                 color: "yellow",
                 size: 1
               }
             }
    end

    test "adds errors for invalid data boolean field assignment" do
      invalid_params = %{
        "likes_to_eat_potato" => "no"
      }

      # Needs to be dynamic to avoid warnings
      changeset = apply(Foo, :changeset, [%{__struct__: Foo}, invalid_params])

      refute changeset.valid?

      # error assertions
      assert Ecto.Changeset.traverse_errors(changeset, & &1) == %{
               likes_to_eat_potato: [{"is invalid", [type: :boolean, validation: :cast]}]
             }
    end

    test "adds errors for invalid data string field assignment" do
      invalid_params = %{
        "title" => 1
      }

      # Needs to be dynamic to avoid warnings
      changeset = apply(Foo, :changeset, [%{__struct__: Foo}, invalid_params])

      refute changeset.valid?

      # error assertions
      assert Ecto.Changeset.traverse_errors(changeset, & &1) == %{
               title: [{"is invalid", [type: :string, validation: :cast]}]
             }
    end

    test "adds errors for invalid number field assignment" do
      invalid_params = %{
        "favorite_number" => "one"
      }

      # Needs to be dynamic to avoid warnings
      changeset = apply(Foo, :changeset, [%{__struct__: Foo}, invalid_params])

      refute changeset.valid?

      # error assertions
      assert Ecto.Changeset.traverse_errors(changeset, & &1) == %{
               favorite_number: [{"is invalid", [type: :decimal, validation: :cast]}]
             }
    end

    test "adds errors for invalid data array field assignment" do
      invalid_params = %{
        "names" => [1]
      }

      # Needs to be dynamic to avoid warnings
      changeset = apply(Foo, :changeset, [%{__struct__: Foo}, invalid_params])

      refute changeset.valid?

      # error assertions
      assert Ecto.Changeset.traverse_errors(changeset, & &1) == %{
               names: [{"is invalid", [type: {:array, :string}, validation: :cast]}]
             }
    end

    test "adds errors for invalid data array-of-objects field assignment" do
      invalid_params = %{
        "cars" => [
          %{"color" => "apple red"},
          %{"color" => "banana yellow"},
          %{}
        ]
      }

      # Needs to be dynamic to avoid warnings
      changeset = apply(Foo, :changeset, [%{__struct__: Foo}, invalid_params])

      refute changeset.valid?

      # error assertions
      assert Ecto.Changeset.traverse_errors(changeset, & &1) == %{
               cars: [
                 %{},
                 %{},
                 %{
                   color: [
                     {"Required property color was not present.", []}
                   ]
                 }
               ]
             }
    end

    test "adds errors for mulitple required fields" do
      invalid_params = %{
        "truck" => %{}
      }

      # Needs to be dynamic to avoid warnings
      changeset = apply(Foo, :changeset, [%{__struct__: Foo}, invalid_params])

      refute changeset.valid?

      # error assertions
      assert Ecto.Changeset.traverse_errors(changeset, & &1) == %{
               truck: %{
                 color: [
                   {"Required property color was not present.", []}
                 ],
                 size: [
                   {"Required property size was not present.", []}
                 ]
               }
             }
    end
  end
end
