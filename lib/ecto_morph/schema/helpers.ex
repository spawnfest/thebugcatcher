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
    nested_errors = Keyword.get_values(changeset.errors, :nested_ecto_morph_errors)
    errors = Keyword.delete(changeset.errors, :nested_ecto_morph_errors)

    changeset = %{changeset | errors: errors}

    if length(nested_errors) >= 1 do
      Enum.reduce(nested_errors, changeset, fn {msg, keys}, changeset ->
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

  defp apply_field_path_error(changeset_list, msg, [n | tail]) when is_integer(n) do
    List.update_at(changeset_list, n, fn field_changeset ->
      apply_field_path_error(field_changeset, msg, tail)
    end)
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

      changeset_list when is_list(changeset_list) ->
        case tail do
          [n] when is_integer(n) ->
            changeset_list =
              changeset_list
              |> List.update_at(n, fn field_changeset ->
                Ecto.Changeset.add_error(field_changeset, field, msg)
              end)

            Ecto.Changeset.put_change(
              changeset,
              field,
              changeset_list
            )

          _ ->
            Ecto.Changeset.put_change(
              changeset,
              field,
              apply_field_path_error(changeset_list, msg, tail)
            )
        end

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
        cond do
          msg =~ ~r/Required property/ ->
            required_field =
              Regex.named_captures(~r/Required property (?<field>\w+) was not present./, msg)
              |> Map.get("field")
              |> String.to_atom()

            Ecto.Changeset.add_error(
              changeset,
              :nested_ecto_morph_errors,
              msg,
              fields: [field] ++ [required_field]
            )

          msg =~ ~r/Required properties/ ->
            required_fields =
              Regex.named_captures(
                ~r/Required properties (?<fields>[\w|,|\s]*) were not present./,
                msg
              )
              |> Map.get("fields")
              |> String.split(", ")
              |> Enum.map(&String.to_atom/1)

            Enum.reduce(required_fields, changeset, fn required_field, cs ->
              Ecto.Changeset.add_error(
                cs,
                :nested_ecto_morph_errors,
                "Required property #{required_field} was not present.",
                fields: [field] ++ [required_field]
              )
            end)

          true ->
            Ecto.Changeset.add_error(changeset, field, msg)
        end

      _ ->
        # "Required property #{missing} was not present."
        # "Required properties #{Enum.join(missing, ", ")} were not present."
        cond do
          msg =~ ~r/Required property/ ->
            required_field =
              Regex.named_captures(~r/Required property (?<field>\w+) was not present./, msg)
              |> Map.get("field")
              |> String.to_atom()

            Ecto.Changeset.add_error(
              changeset,
              :nested_ecto_morph_errors,
              msg,
              fields: fields ++ [required_field]
            )

          msg =~ ~r/Required properties/ ->
            required_fields =
              Regex.named_captures(
                ~r/Required properties (?<fields>[\w|,|\s]*) were not present./,
                msg
              )
              |> Map.get("fields")
              |> String.split(", ")
              |> Enum.map(&String.to_atom/1)

            Enum.reduce(required_fields, changeset, fn required_field, cs ->
              Ecto.Changeset.add_error(
                cs,
                :nested_ecto_morph_errors,
                "Required property #{required_field} was not present.",
                fields: fields ++ [required_field]
              )
            end)

          true ->
            Ecto.Changeset.add_error(
              changeset,
              :nested_ecto_morph_errors,
              msg,
              fields: fields
            )
        end
    end
  end

  def field_from_path(path) do
    String.split(path, "#/")
    |> Enum.at(-1)
    |> String.split("/")
    |> Enum.map(fn v ->
      case Integer.parse(v) do
        {int, _} ->
          int

        :error ->
          String.to_atom(v)
      end
    end)
  end
end
