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
    quote location: :keep do
      case unquote(schema_property) do
        %{"$ref" => id} ->
          # TODO: Find module and embed
          "TODO"

        %{"type" => "object", "properties" => _} ->
          EctoMorph.embed_one_inline_schema(unquote(key), unquote(schema_property))

        %{"type" => _type} ->
          field(:"#{unquote(key)}", EctoMorph.type_for_schema_property(unquote(schema_property)))
      end
    end
  end

  defmacro embed_one_inline_schema(key, schema_property) do
    quote location: :keep do
      EctoMorph.define_current_schema_property(unquote(schema_property))

      embeds_one :"#{unquote(key)}", :"#{Macro.camelize(unquote(key))}" do
        current_schema_property = EctoMorph.current_schema_property()

        Enum.each(current_schema_property["properties"], fn {inner_key, inner_schema_property} ->
          EctoMorph.add_ecto_field(inner_key, inner_schema_property)
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
        require EctoMorph

        @schema unquote(resolved_schema)
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
          |> cast_fields()
          |> maybe_validate_json_schema()
          |> maybe_apply_nested_ecto_morph_errors()
        end

        defp cast_fields_if_valid(%{valid?: true} = changeset) do
          cast_fields(changeset, __MODULE__, changeset.params)
        end

        defp cast_fields_if_valid(changeset), do: changeset

        defp cast_fields(changeset) do
          cast_fields(changeset, __MODULE__, changeset.params)
        end

        defp cast_fields(changeset_or_struct, schema_mod, params) do
          embeds = schema_mod.__schema__(:embeds)
          changeset = cast(changeset_or_struct, params, schema_mod.__schema__(:fields) -- embeds)

          changeset =
            Enum.reduce(embeds, changeset, fn embed, changeset ->
              type_module = schema_mod.__schema__(:embed, embed).related

              cast_embed(changeset, embed,
                with: fn struct, embed_params ->
                  cast_fields(struct, type_module, embed_params)
                end
              )
            end)

          changeset
        end

        def maybe_apply_nested_ecto_morph_errors(%{valid?: true} = changeset) do
          changeset
        end

        def maybe_apply_nested_ecto_morph_errors(changeset) do
          errors = Keyword.get_values(changeset.errors, :nested_ecto_morph_errors)

          if length(errors) >= 1 do
            Enum.reduce(errors, changeset, fn {msg, keys}, changeset ->
              fields = Keyword.fetch!(keys, :fields)
              apply_field_path_error(changeset, msg, fields)
            end)
          else
            changeset
          end
        end

        def apply_field_path_error(changeset, msg, [field]) do
          add_error(changeset, field, msg)
        end

        def apply_field_path_error(changeset, msg, [field | tail]) do
          field_changeset = get_change(changeset, field)

          put_change(
            changeset,
            field,
            apply_field_path_error(field_changeset, msg, tail)
          )
        end

        defp maybe_validate_json_schema(%{valid?: false} = changeset) do
          changeset
        end

        defp maybe_validate_json_schema(%{valid?: true} = changeset) do
          case ExJsonSchema.Validator.validate(@schema, changeset.params) do
            :ok ->
              changeset

            {:error, errors} ->
              Enum.reduce(errors, changeset, fn {msg, path}, changeset ->
                fields = field_from_path(path)

                if length(fields) == 1 do
                  [field] = fields
                  add_error(changeset, field, msg)
                else
                  changeset
                  |> add_error(:nested_ecto_morph_errors, msg, fields: fields)
                end
              end)
          end
        end

        defp field_from_path(path) do
          String.split(path, "#/")
          |> Enum.at(-1)
          |> String.split("/")
          |> Enum.map(&String.to_atom/1)
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

  defmodule Nested do
    def __schema__(:primary_key) do
      %{}
    end

    def __struct__() do
      %{}
    end
  end

  def schemaless_changeset(data, attrs, schema, node \\ nil) do
    properties = node["properties"] || schema.schema["properties"]

    types = Enum.reduce(properties, %{}, fn {key, schema_property}, acc ->
      type = type_for_schema_property(schema_property)
      Map.put(acc, String.to_atom(key), type)
    end)

    {embed_keys, cast_keys} = Enum.split_with(types, fn
      {_key, {:embed, _}} ->
        true
      _ ->
        false
     end)

    # Convert from keyword list to map
    cast_keys = Enum.into(cast_keys, %{})
    embed_keys = Enum.into(embed_keys, %{})

    changeset = {data, types}
      |> Ecto.Changeset.cast(attrs, Map.keys(cast_keys))

    changeset = Enum.reduce(embed_keys, changeset, fn {key, _}, changeset ->
      child_properties = Map.get(properties, Atom.to_string(key))

      Ecto.Changeset.cast_embed(changeset, key, with: fn struct, attrs -> schemaless_changeset(struct, attrs, schema, child_properties) end)
    end)

    if changeset.valid? do
      # case ExJsonSchema.Validator.validate(@schema, changeset.params) do
      #   :ok ->
      #     changeset
      #
      #   {:error, errors} ->
      #     Enum.reduce(errors, changeset, fn {msg, path}, changeset ->
      #       field = field_from_path(path)
      #       add_error(changeset, :"#{field}", msg)
      #     end)
      # end
      changeset
    else
      changeset
    end

    # child = Ecto.Changeset.get_field(changeset, :child)
    #
    # child = Ecto.Changeset.change({child, %{name: :string}})
    # # child = schemaless_changeset(changeset, schema.child?, [])
    #
    # changeset = changeset
    #   |> Ecto.Changeset.put_change(:child, child)
    #
    # types = changeset.types
    #   |> Map.put(:child, {:embed,
    #      %Ecto.Embedded{
    #        cardinality: :one,
    #        field: :child,
    #        # on_cast: fn struct, params -> schema_module.changeset(struct, params) end,
    #        on_cast: fn struct, params -> nil end,
    #        on_replace: :raise,
    #        ordered: true,
    #        owner: nil,
    #        related: nil,
    #        unique: true
    #      }}
    #   )

    # %{changeset | types: types}
  end
end
