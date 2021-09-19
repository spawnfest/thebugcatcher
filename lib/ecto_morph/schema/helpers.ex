defmodule EctoMorph.Schema.Helpers do
  @moduledoc """
  Helper functions for an EctoMorph.Schema
  """

  @doc """
  Recursively casts fields for nested changesets
  """
  def recursive_cast_fields_for(changeset_or_struct, schema_mod, params) do
    embeds_fields = schema_mod.__schema__(:embeds)
    all_fields = schema_mod.__schema__(:fields)

    changeset_or_struct
    |> Ecto.Changeset.cast(params, all_fields -- embeds_fields)
    |> cast_embedded_fields(embeds_fields)
  end

  defp cast_embedded_fields(changeset, embeds) do
    Enum.reduce(embeds, changeset, &cast_embedded_field/2)
  end

  defp cast_embedded_field(embed, changeset) do
    schema_mod = changeset.data.__struct__
    type_module = schema_mod.__schema__(:embed, embed).related

    Ecto.Changeset.cast_embed(changeset, embed,
      with: fn struct, embed_params ->
        recursive_cast_fields_for(struct, type_module, embed_params)
      end
    )
  end

  @doc """
  Applies error from `nested_ecto_morph_errors` field to Ecto.Changeset nested
  under fields

  Doesn't apply if changeset is valid
  """
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

  defp apply_field_path_error(changeset, msg, [field]) do
    Ecto.Changeset.add_error(changeset, field, msg)
  end

  defp apply_field_path_error(changeset, msg, [field | tail]) do
    field_changeset = Ecto.Changeset.get_change(changeset, field)

    case field_changeset do
      %Ecto.Changeset{} ->
        Ecto.Changeset.put_change(
          changeset,
          field,
          apply_field_path_error(field_changeset, msg, tail)
        )

      _ ->
        changeset
    end
  end

  def validate_json_schema(%{valid?: true} = changeset, schema) do
    case ExJsonSchema.Validator.validate(schema, changeset.params) do
      :ok -> changeset
      {:error, errors} -> add_json_schema_errors(changeset, errors)
    end
  end

  defp add_json_schema_errors(changeset, errors) do
    Enum.reduce(errors, changeset, &add_json_schema_error/2)
  end

  defp add_json_schema_error({msg, path}, changeset) do
    fields = field_from_path(path)

    case fields do
      [field] ->
        Ecto.Changeset.add_error(changeset, field, msg)

      _ ->
        Ecto.Changeset.add_error(
          changeset,
          :nested_ecto_morph_errors,
          msg,
          fields: fields
        )
    end
  end

  def field_from_path(path) do
    String.split(path, "#/")
    |> Enum.at(-1)
    |> String.split("/")
    |> Enum.map(&String.to_atom/1)
  end
end
