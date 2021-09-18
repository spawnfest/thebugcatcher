defmodule EctoMorph.FieldTypeResolver do
  @moduledoc """
  Documentation for `EctoMorph.FieldTypeResolver`.

  ### Usage
  
  Invoke `run/1` to resolve a type:

  ```
  EctoMorph.FieldTypeResolver.run("string")
  ```

  """

  def run("string"), do: :string
  def run(type), do: raise_error_for_unsupported_type(type)

  defp raise_error_for_unsupported_type(type) do
    raise "Type resolution NOT SUPPORTED! (type: #{type})"
  end
end
