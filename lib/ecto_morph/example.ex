defmodule EctoMorph.Example do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :foo, :map
  end

  def changeset(example, attrs) do
    example
    |> cast(attrs, [:foo])
    |> cast_json_schema(:foo, schema_module())
  end

  def cast_json_schema(changeset, field, schema_module) do
    schema_params = get_field(changeset, field)

    case schema_module.changeset(%{__struct__: schema_module}, schema_params) do
      %Ecto.Changeset{valid?: true} = schema_changeset ->
        field_value =
          schema_changeset
          |> apply_changes()
          |> Map.from_struct()

        put_change(changeset, field, field_value)

      %Ecto.Changeset{errors: errors} ->
        Enum.reduce(errors, changeset, fn error, changeset ->
          add_error(changeset, field, error)
        end)
    end
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
      } |> ExJsonSchema.Schema.resolve()
  end
end
