defmodule EctoMorph.FileUtilsTest do
  use ExUnit.Case

  alias EctoMorph.FileUtils

  describe "ls_r!/1" do
    setup tags do
      ## Kick-off
      path = tags[:path]
      results = FileUtils.ls_r!(path)

      {:ok, results: results}
    end

    @tag path: "./test/support/file_utils_test/"
    test "recursively lists files in the path if directory",
         %{results: results} do
      expected_results = [
        "./test/support/file_utils_test/file3",
        "./test/support/file_utils_test/file2",
        "./test/support/file_utils_test/folder2/folder2_1/file",
        "./test/support/file_utils_test/file1",
        "./test/support/file_utils_test/folder1/file"
      ]

      assert Enum.sort(results) == Enum.sort(expected_results)
    end

    @tag path: "./test/support/file_utils_test/file1"
    test "lists the path itself if that path is a file",
         %{results: results} do
      expected_results = ["./test/support/file_utils_test/file1"]

      assert results == expected_results
    end

    @tag path: "./test/support/file_utils_test/badfile"
    test "returns empty list if path doesn't exist", %{results: results} do
      expected_results = []

      assert results == expected_results
    end
  end
end
