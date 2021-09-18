defmodule ChangeMe.Example do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :foo, :map
  end

  def changeset(example, attrs) do
    example
    |> cast(attrs, [:foo])
    |> cast_json_schema(:foo, foo_schema())
  end

  def cast_json_schema(changeset, field, schema) do
    schema_params = get_field(changeset, field)

    case ExJsonSchema.Validator.validate(schema, schema_params) do
      :ok ->
        changeset
      {:error, errors} ->
        Enum.reduce(errors, changeset, fn {msg, path}, changeset ->
          add_error(changeset, field, msg <> " " <> path)
        end)
    end
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
