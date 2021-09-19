defmodule EctoMorph.Schema.HelpersTest do
  use ExUnit.Case

  alias EctoMorph.Schema.Helpers

  defmodule ExampleSchema do
    @moduledoc false

    use Ecto.Schema

    embedded_schema do
      field(:name, :string)

      embeds_one :child, Child do
        field(:child_name, :string)

        embeds_many :grand_children, GrandChild do
          field(:grand_child_name, :string)
        end
      end
    end
  end

  @valid_params %{
    name: "Bob",
    child: %{
      child_name: "Betty",
      grand_children: [
        %{grand_child_name: "John"},
        %{grand_child_name: "Mary"}
      ]
    }
  }

  describe "recursive_cast_fields_for/3" do
    test "casts recursively fields for nested changesets" do
      ## Kick-off
      changeset =
        Helpers.recursive_cast_fields_for(
          %ExampleSchema{},
          ExampleSchema,
          @valid_params
        )

      struct = Ecto.Changeset.apply_changes(changeset)

      expected_struct = %ExampleSchema{
        name: @valid_params[:name],
        child: %ExampleSchema.Child{
          child_name: get_in(@valid_params, [:child, :child_name]),
          grand_children:
            @valid_params
            |> get_in([:child, :grand_children])
            |> Enum.map(&struct!(ExampleSchema.Child.GrandChild, &1))
        }
      }

      assert struct == expected_struct
    end
  end

  describe "maybe_apply_nested_ecto_morph_errors/1" do
    test "returns the changeset if valid" do
      changeset = Ecto.Changeset.cast(%ExampleSchema{}, %{}, [])

      assert changeset.valid?

      ## Kick-off
      returned_changeset = Helpers.maybe_apply_nested_ecto_morph_errors(changeset)

      assert returned_changeset == changeset
    end

    test "returns the changeset if no nested_ecto_morph_errors" do
      changeset =
        %ExampleSchema{}
        |> Ecto.Changeset.cast(%{}, [])
        |> Ecto.Changeset.validate_required([:name])

      refute changeset.valid?

      ## Kick-off
      returned_changeset = Helpers.maybe_apply_nested_ecto_morph_errors(changeset)

      assert returned_changeset == changeset
    end

    test "returns the same changeset when nested_ecto_morph_errors without " <>
           "nested params" do
      changeset =
        %ExampleSchema{}
        |> Ecto.Changeset.cast(%{}, [])
        |> Ecto.Changeset.add_error(
          :nested_ecto_morph_errors,
          "Child Error",
          fields: [:child, :child_name]
        )

      refute changeset.valid?

      ## Kick-off
      returned_changeset = Helpers.maybe_apply_nested_ecto_morph_errors(changeset)

      assert returned_changeset == changeset
    end

    test "returns changeset with errors when nested_ecto_morph_errors with " <>
           "nested params" do
      changeset =
        %ExampleSchema{}
        |> Helpers.recursive_cast_fields_for(ExampleSchema, @valid_params)
        |> Ecto.Changeset.add_error(
          :nested_ecto_morph_errors,
          "Child Error",
          fields: [:child, :child_name]
        )
        |> Ecto.Changeset.add_error(
          :nested_ecto_morph_errors,
          "Grand Child Error",
          fields: [:child, :grand_children, :grand_child_name]
        )

      refute changeset.valid?

      ## Kick-off
      returned_changeset = Helpers.maybe_apply_nested_ecto_morph_errors(changeset)

      refute returned_changeset == changeset

      assert returned_changeset.changes.child.errors == [
               child_name: {"Child Error", []}
             ]

      grand_children_changesets = returned_changeset.changes.child.changes.grand_children
      assert grand_children_changesets == []
    end
  end
end
