defmodule EctoMorph do
  @moduledoc """
  Documentation for `EctoMorph`.
  """
  def validate(_, _) do
  end

  defmodule FileUtils do
    def ls_r!(path \\ ".") do
      cond do
        File.regular?(path) ->
          [path]

        File.dir?(path) ->
          path
          |> File.ls!()
          |> Enum.map(&Path.join(path, &1))
          |> Enum.map(&ls_r!/1)
          |> Enum.concat()

        true ->
          []
      end
    end 
  end

  defmodule Config do
    @app_name :ecto_morph
    @default_json_schemas_path "priv/ecto_morph"

    def json_schemas_path() do
      @app_name
      |> Application.get_env(:json_schemas_path, @default_json_schemas_path)
    end
  end

  def load_json_schemas!() do
    Config.json_schemas_path()
    |> FileUtils.ls_r!()
    |> Enum.each(fn json_schema_path -> 
      load_json_schema!(json_schema_path) 
    end)
  end

  def load_json_schema!(file_path) do
    file_path
    |> File.read()
    |> Jason.decode()
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
            field(:"#{key}", :"#{type}")
          end)
        end

        def changeset(%__MODULE__{} = struct, params) do
          struct
          |> cast(params, [])
          |> validate()
          |> cast_fields_if_valid()
        end

        defp cast_fields_if_valid(%{valid?: true} = changeset) do
          cast(changeset, changeset.params, __schema__(:fields))
        end

        defp cast_fields_if_valid(changeset), do: changeset

        defp validate(changeset) do
          case ExJsonSchema.Validator.validate(@schema, changeset.params) do
            :ok ->
              changeset

            {:error, errors} ->
              Enum.reduce(errors, changeset, fn {msg, path}, changeset ->
                field = field_from_path(path)
                add_error(changeset, :"#{field}", msg)
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
