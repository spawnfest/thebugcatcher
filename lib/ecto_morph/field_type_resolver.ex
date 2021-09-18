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

  def run(type, format), do: raise_error_for_unsupported_type(type, format)

  defp raise_error_for_unsupported_type(type, format \\ nil) do
    raise "Type resolution NOT SUPPORTED! (type: #{type}, format: #{format})"
  end
end
