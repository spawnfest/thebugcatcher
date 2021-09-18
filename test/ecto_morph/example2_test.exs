defmodule EctoMorph.Example2Test do
  use ExUnit.Case

  alias EctoMorph.Example2

  # setup do
  #   :ok
  # end

  test "casts valid data" do
    example = %Example2{}

    changeset = Example2.changeset(example, %{"foo" => %{"foo" => "bar"}})

    assert changeset.valid?

    struct = Ecto.Changeset.apply_changes(changeset)

    assert struct == %Example2{foo: %Example2.Foo{foo: "bar"}, id: nil}
  end

  test "adds errors for invalid data" do
    example = %Example2{}

    changeset = Example2.changeset(example, %{"foo" => %{"foo" => 1}})

    refute changeset.valid?

    assert Ecto.Changeset.traverse_errors(changeset, & &1) == %{
             foo: %{
               foo: [{"is invalid", [type: :string, validation: :cast]}]
             }
           }
  end
end
