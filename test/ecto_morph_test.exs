defmodule EctoMorphTest do
  use ExUnit.Case

  describe "validate/2" do
  end

  describe "load_json_schemas!/0" do
    test "loads json schemas from the config layer" do
      EctoMorph.load_json_schemas!()
    end
  end
end
