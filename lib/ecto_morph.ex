defmodule EctoMorph do
  @moduledoc """
  Documentation for `EctoMorph`.
  """
  def validate(_, _) do
  end


  defmacro define_ecto_schema_from_json(name, ex_json_schema) do
    # Only create Ecto.Schema for objects type
    quote bind_quoted: [schema: ex_json_schema, name: name], location: :keep do
      defmodule :"#{name}" do
        use Ecto.Schema
        import Ecto.Changeset

        @schema schema
        @properties @schema.schema["properties"]

        @primary_key nil
        embedded_schema do
          Enum.each(@properties, fn {key, %{"type" => type}} ->
            field :"#{key}", :"#{type}"
          end)
        end

        def changeset(%__MODULE__{} = struct, params) do
          struct
          |> cast(params, [])
          |> validate()
          # TODO: If valid
          # |> cast(params, __schema__(:fields))
        end

        defp validate(changeset) do
          case ExJsonSchema.Validator.validate(@schema, changeset.params) do
            :ok ->
              changeset
            {:error, errors} ->
              Enum.reduce(errors, changeset, fn {msg, path}, changeset ->
                field = field_from_path(path)
                add_error(changeset, field, msg)
              end)
          end
        end

        defp field_from_path(path) do
          String.split(path, "#/") |> Enum.at(-1)
        end
      end
    end
  end
end
