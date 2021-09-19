defmodule EctoMorph.FieldTypeResolver do
  @moduledoc """
  Documentation for `EctoMorph.FieldTypeResolver`.

  ### Usage

  Invoke `run/1` to resolve a type:

  ```
  EctoMorph.FieldTypeResolver.run("string")
  ```

  """

  def run(type, format \\ nil)

  def run("string", "date-time"), do: :utc_datetime
  def run("string", _), do: :string

  def run("object", _),
    do:
      {:embed,
       %Ecto.Embedded{
         cardinality: :one,
         field: :todo,
         # on_cast: fn struct, params -> schema_module.changeset(struct, params) end,
         on_cast: fn struct, params -> 1 end,
         on_replace: :raise,
         ordered: true,
         owner: 2,
         related: EctoMorph.Nested,
         unique: true
       }}

  # def run("object", _), do: :map

  def run(type, format), do: raise_error_for_unsupported_type(type, format)

  defp raise_error_for_unsupported_type(type, format \\ nil) do
    raise "Type resolution NOT SUPPORTED! (type: #{type}, format: #{format})"
  end
end
