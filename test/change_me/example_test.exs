defmodule ChangeMe.ExampleTest do
  use ExUnit.Case

  test "casts valid data" do
    example = %ChangeMe.Example{}

    changeset = ChangeMe.Example.changeset(example, %{"foo" => %{"foo" => "bar"}})

    assert changeset.valid?
  end

  test "adds errors for invalid data" do
    example = %ChangeMe.Example{}

    changeset = ChangeMe.Example.changeset(example, %{"foo" => %{"foo" => 1}})

    refute changeset.valid?
    assert changeset.errors == [foo: {"Type mismatch. Expected String but got Integer. #/foo", []}]
  end
end
