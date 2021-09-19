defmodule EctoMorph do
  @moduledoc """
  Documentation for `EctoMorph`.
  """
  alias EctoMorph.{Config, FileUtils}

  def validate(_, _) do
  end

  def type_for_schema_property(%{"type" => type, "format" => format}) do
    EctoMorph.FieldTypeResolver.run(type, format)
  end

  def type_for_schema_property(%{"type" => type}) do
    EctoMorph.FieldTypeResolver.run(type)
  end

  defmacro add_ecto_field(key, schema_property, schema) do
    quote location: :keep do
      case unquote(schema_property) do
        # e.g.) [:root, "$defs", "name"]
        %{"$ref" => [:root | relative_refs_path]} ->
          schema_property = get_in(unquote(schema).schema, relative_refs_path)

          case schema_property do
            %{"type" => "object", "properties" => _} ->
              EctoMorph.embed_one_inline_schema(unquote(key), schema_property, unquote(schema))

            %{"type" => _type} ->
              field(:"#{unquote(key)}", EctoMorph.type_for_schema_property(schema_property))
          end

        %{"type" => "object", "properties" => _} ->
          EctoMorph.embed_one_inline_schema(
            unquote(key),
            unquote(schema_property),
            unquote(schema)
          )

        %{"type" => _type} ->
          field(:"#{unquote(key)}", EctoMorph.type_for_schema_property(unquote(schema_property)))
      end
    end
  end

  defmacro embed_one_inline_schema(key, schema_property, schema) do
    quote location: :keep do
      EctoMorph.define_current_schema_property(unquote(schema_property))

      embeds_one :"#{unquote(key)}", :"#{Macro.camelize(unquote(key))}" do
        current_schema_property = EctoMorph.current_schema_property()

        Enum.each(current_schema_property["properties"], fn {inner_key, inner_schema_property} ->
          EctoMorph.add_ecto_field(inner_key, inner_schema_property, unquote(schema))
        end)
      end

      EctoMorph.undefine_current_schema_property()
    end
  end

  def define_current_schema_property(schema_property) do
    Agent.start_link(fn -> schema_property end, name: :current_ecto_morph_schema_property)
  end

  def current_schema_property do
    Agent.get(:current_ecto_morph_schema_property, & &1)
  end

  def undefine_current_schema_property do
    if Process.whereis(:current_ecto_morph_schema_property) do
      Agent.stop(:current_ecto_morph_schema_property)
    end
  end

  defmacro define_ecto_schema_from_json(name, resolved_schema) do
    # Only create Ecto.Schema for objects type
    quote location: :keep do
      defmodule :"#{unquote(name)}" do
        use Ecto.Schema
        import Ecto.Changeset
        import EctoMorph.Schema.Helpers

        require EctoMorph

        @schema unquote(resolved_schema)
        @properties @schema.schema["properties"]

        @primary_key nil
        embedded_schema do
          Enum.each(@properties, fn {key, schema_property} ->
            EctoMorph.add_ecto_field(key, schema_property, @schema)
          end)
        end

        def changeset(%__MODULE__{} = struct, params) do
          struct
          |> cast(params, [])
          |> cast_fields()
          |> maybe_validate_json_schema()
          |> maybe_apply_nested_ecto_morph_errors()
        end

        defp cast_fields(changeset) do
          recursive_cast_fields_for(
            changeset,
            __MODULE__,
            changeset.params
          )
        end

        def maybe_validate_json_schema(%{valid?: false} = changeset) do
          changeset
        end

        def maybe_validate_json_schema(%{valid?: true} = changeset) do
          validate_json_schema(changeset, @schema)
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
end
