defmodule EctoMorph.Example do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:foo, :map)
  end

  def changeset(example, attrs) do
    example
    |> cast(attrs, [:foo])
    |> cast_json_schema(:foo, schema_module())
  end

  def cast_json_schema(changeset, field, schema_module) do
    schema_params = get_field(changeset, field)

    schema_changeset = schema_module.changeset(%{__struct__: schema_module}, schema_params)

    new_types = %{
      changeset.types
      | :"#{field}" =>
          {:embed,
           %Ecto.Embedded{
             cardinality: :one,
             field: field,
             on_cast: fn struct, params -> schema_module.changeset(struct, params) end,
             on_replace: :raise,
             ordered: true,
             owner: __MODULE__,
             related: schema_module,
             unique: true
           }}
    }

    changeset = %{changeset | types: new_types}

    changeset
    |> put_change(field, schema_changeset)
  end

  def schema_module do
    Foo
  end

  def foo_schema do
    %{
      "type" => "object",
      "properties" => %{
        "foo" => %{
          "type" => "string"
        }
      }
    }
    |> ExJsonSchema.Schema.resolve()
  end
end
