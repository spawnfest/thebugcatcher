defmodule EctoMorph.Schema.Definer do
  @moduledoc """
  This module is responsible for defining an EctoMorph Schema
  """

  defmacro add_ecto_field(key, schema_property, schema) do
    quote location: :keep do
      case unquote(schema_property) do
        # e.g.) [:root, "$defs", "name"]
        %{"$ref" => [:root | relative_refs_path]} ->
          schema_property = get_in(unquote(schema).schema, relative_refs_path)

          case schema_property do
            %{"type" => "object", "properties" => _} ->
              embed_one_inline_schema(unquote(key), schema_property, unquote(schema))

            %{"type" => _type} ->
              field(:"#{unquote(key)}", EctoMorph.type_for_schema_property(schema_property))
          end

        %{"type" => "object", "properties" => _} ->
          embed_one_inline_schema(
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
      define_current_schema_property(unquote(schema_property))

      embeds_one :"#{unquote(key)}", :"#{Macro.camelize(unquote(key))}" do
        current_schema_property = current_schema_property()

        Enum.each(current_schema_property["properties"], fn {inner_key, inner_schema_property} ->
          add_ecto_field(inner_key, inner_schema_property, unquote(schema))
        end)
      end

      undefine_current_schema_property()
    end
  end

  def define_current_schema_property(schema_property) do
    Agent.start_link(
      fn -> schema_property end,
      name: :current_ecto_morph_schema_property
    )
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
        import EctoMorph.Schema.Definer

        @schema unquote(resolved_schema)
        @properties @schema.schema["properties"]

        @primary_key nil
        embedded_schema do
          Enum.each(@properties, fn {key, schema_property} ->
            add_ecto_field(key, schema_property, @schema)
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

        defp maybe_validate_json_schema(%{valid?: false} = changeset) do
          changeset
        end

        defp maybe_validate_json_schema(%{valid?: true} = changeset) do
          validate_json_schema(changeset, @schema)
        end
      end
    end
  end
end
