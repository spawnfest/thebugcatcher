defmodule ExJsonSchema.Validator.OneOf do
  @moduledoc """
  `ExJsonSchema.Validator` implementation for `"oneOf"` attributes.

  See:

  """

  alias ExJsonSchema.Validator
  alias ExJsonSchema.Validator.Error

  @behaviour ExJsonSchema.Validator

  @impl ExJsonSchema.Validator
  def validate(root, _, {"oneOf", one_of}, data, path) do
    do_validate(root, one_of, data, path)
  end

  def validate(_, _, _, _, _) do
    []
  end

  defp do_validate(root, one_of, data, path) do
    {valid_count, valid_indices, errors} =
      one_of
      |> Enum.with_index()
      |> Enum.reduce({0, [], []}, fn
        {schema, index}, {valid_count, valid_indices, errors} ->
          case Validator.validation_errors(root, schema, data, path) do
            [] -> {valid_count + 1, [index | valid_indices], errors}
            e -> {valid_count, valid_indices, [{e, index} | errors]}
          end
      end)

    case valid_count do
      1 ->
        []

      0 ->
        [
          %Error{
            error: %Error.OneOf{
              valid_indices: [],
              invalid: errors |> Enum.reverse() |> Validator.map_to_invalid_errors()
            }
          }
        ]

      _ ->
        [%Error{error: %Error.OneOf{valid_indices: Enum.reverse(valid_indices), invalid: []}}]
    end
  end
end
