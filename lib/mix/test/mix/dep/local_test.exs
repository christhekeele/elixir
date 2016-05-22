Code.require_file "../../test_helper.exs", __DIR__

defmodule Mix.Dep.LocalTest do
  use MixTest.Case

  setup do
    Mix.Project.push MixTest.Case.Sample
    :ok
  end

  test "creates new local dep config files", context do
    in_tmp context.test, fn ->
      Mix.Dep.Local.write %{foo: :bar}
      assert File.regular? "mix.local"
    end
  end

  test "raises a proper error for merge conflicts", context do
    in_tmp context.test, fn ->
      File.write "mix.local", ~S"""
      %{"dep": {:hex, :dep, "0.1.0"},
      <<<<<<< HEAD
        "foo": {:hex, :foo, "0.1.0"},
      =======
        "bar": {:hex, :bar, "0.1.0"},
      >>>>>>> foobar
        "baz": {:hex, :baz, "0.1.0"}}
      """
      assert_raise Mix.Error, ~r/Your mix\.local contains merge conflicts/, fn ->
        Mix.Dep.Local.read()
      end
    end
  end
end
