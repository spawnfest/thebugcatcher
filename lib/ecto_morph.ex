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

  def type_for_schema_property(%{"type" => type, "format" => format}) do
    EctoMorph.FieldTypeResolver.run(type, format)
  end

  def type_for_schema_property(%{"type" => type}) do
    EctoMorph.FieldTypeResolver.run(type)
  end

  defmacro add_ecto_field(key, schema_property) do
    quote bind_quoted: [key: key, schema_property: schema_property], location: :keep do
      case schema_property do
        %{"type" => "object"} ->
          "TODO"
        _ ->
          field(:"#{key}", EctoMorph.type_for_schema_property(schema_property))
      end
    end
  end

  defmacro define_ecto_schema_from_json(name, resolved_schema) do
    # Only create Ecto.Schema for objects type
    quote bind_quoted: [schema: resolved_schema, name: name], location: :keep do
      defmodule :"#{name}" do
        use Ecto.Schema
        import Ecto.Changeset
        require EctoMorph

        @schema schema
        @properties @schema.schema["properties"]

        @primary_key nil
        embedded_schema do
          Enum.each(@properties, fn {key, schema_property} ->
            EctoMorph.add_ecto_field(key, schema_property)
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

  def load_json_schemas!() do
    Config.json_schemas_path()
    |> FileUtils.ls_r!()
    |> Enum.each(fn json_schema_path ->
      load_json_schema!(json_schema_path)
    end)
  end

  def load_json_schema!(file_path) do
    resolved_schema = resolved_schema_for_file!(file_path)
    module_name = module_from_schema(resolved_schema)

    define_ecto_schema_from_json(module_name, resolved_schema)
  end

  defp resolved_schema_for_file!(file_path) do
    file_path
    |> File.read!()
    |> Jason.decode!()
    |> ExJsonSchema.Schema.resolve()
  end

  def module_from_schema(resolved_schema) do
    schema_id = resolved_schema.schema["$id"]

    module_name = generate_module_name()

    add_to_registry(module_name, schema_id)

    module_name
  end

  defp generate_module_name do
    "Elixir.EctoMorph.Schema.ID" <> (Ecto.UUID.generate() |> Base.encode64())
  end

  def start_link, do: Agent.start_link(fn -> [] end, name: __MODULE__)
  def add_to_registry(module, id), do: Agent.update(__MODULE__, &[{module, id} | &1])
  def get_from_registry(module), do: Agent.get(__MODULE__, & &1) |> Keyword.get(module)
  def get_all_modules, do: Agent.get(__MODULE__, & &1) |> Enum.map(&elem(&1, 0))

  def get_module_for_id(schema_id) do
    Agent.get(__MODULE__, & &1)
    |> Enum.reduce(nil, fn {module, id}, acc ->
      cond do
        not is_nil(acc) ->
          acc

        id == schema_id ->
          module

        true ->
          nil
      end
    end)
  end

  def schemaless_changeset(data, schema, params) do
    properties = schema.schema["properties"]

    types = Enum.reduce(properties, %{}, fn {key, schema_property}, acc ->
      type = type_for_schema_property(schema_property)
      Map.put(acc, String.to_atom(key), type)
    end)

    types = types
      |> Map.put(:child, :map)

    changeset = {data, types}
      |> Ecto.Changeset.cast(params, Map.keys(types))

    child = Ecto.Changeset.get_field(changeset, :child)

    child = Ecto.Changeset.change({child, %{name: :string}})
    # child = schemaless_changeset(changeset, schema.child?, [])

    changeset = changeset
      |> Ecto.Changeset.put_change(:child, child)

    types = changeset.types
      |> Map.put(:child, {:embed,
         %Ecto.Embedded{
           cardinality: :one,
           field: :child,
           # on_cast: fn struct, params -> schema_module.changeset(struct, params) end,
           on_cast: fn struct, params -> nil end,
           on_replace: :raise,
           ordered: true,
           owner: nil,
           related: nil,
           unique: true
         }}
      )

    %{changeset | types: types}
  end
end
