defmodule EctoMorph.Example2 do
  use Ecto.Schema
  import Ecto.Changeset

  defmodule Foo do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :foo, :string
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [:foo])
    end
  end

  embedded_schema do
    embeds_one :foo, Foo 
  end

  def changeset(example, attrs) do
    example
    |> cast(attrs, [])
    |> cast_embed(:foo)
  end
end
