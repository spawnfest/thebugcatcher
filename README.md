<img src="logo/logo.png" href="#" width="270" height="190">

# EctoMorph

Morph between Ecto & JSON Schemas!

## Use Cases

#### Example 1: Injesting JSON data & Coercing to Elixir data

Some Api broadcasts messages that look like:

```elixir
%SomeMessage{
  id: "abcdefghijklmnop-uuid-imsosecure",
  type: "alert",
  data: %{
    priory_level: "high",
    occurred_at: ~N[2020-01-20]
  }
}
```

Our app is subscribed to these messages, and processes them:

```elixir
defmodule MyMessageCenter.MessageProcessor do
  def process(%SomeMessage{} = message) do
    # some super-duper heavy work
  end

  defp find_schema_for_message(%SomeMessage{type: "alert"}), do: AlertSchema
end
```

#### Example 2: Producing a JSON schema from an Ecto schema

Given an existing schema:

```elixir
defmodule MyApp.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema do
    field :potato, :string
  end
end
```

our app can produce

```elixir
defmodule MyApp.JsonSchemaFromEctoSchema do

  @spec run(%MyApp.User{}) :: {:ok, json_string} | {:error, error_string}
  def run(schema) do
    # something
  end
end
```
