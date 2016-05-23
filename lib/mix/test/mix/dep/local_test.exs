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
      %{"foo": {:enabled, "foo/path"},
      <<<<<<< HEAD
        "bar": {:enabled, "bar/path"},
      =======
        "bar": {:disabled, "new/bar/path"},
      >>>>>>> bar
        "baz": {:disabled, "baz/path"}}
      """
      assert_raise Mix.Error, ~r/Your mix\.local contains merge conflicts/, fn ->
        Mix.Dep.Local.read()
      end
    end
  end

  test "deps not in local config are treated normally" do
    local = %{}
    dep = %Mix.Dep{app: :name}
    assert dep == Mix.Dep.check_local(dep, local)
  end

  test "even disabled deps in local config must be fully-specified git deps" do
    local = %{
      git: {:disabled, ""},
      path: {:disabled, ""},
    }

    full_git_dep = %Mix.Dep{app: :git, scm: Mix.SCM.Git, opts: [branch: "master"]}
    assert full_git_dep == Mix.Dep.check_local(full_git_dep, local)

    incomplete_git_dep = %Mix.Dep{app: :git, scm: Mix.SCM.Git}
    assert_raise Mix.Error, ~r/Dependency git found in mix.local config but has not specified a branch, ref, or tag in mix.exs./, fn ->
      Mix.Dep.check_local(incomplete_git_dep, local)
    end

    non_git_dep = %Mix.Dep{app: :path, scm: Mix.SCM.Path}
    assert_raise Mix.Error, ~r/Dependency path found in mix.local config but is not using git in mix.exs./, fn ->
      Mix.Dep.check_local(non_git_dep, local)
    end
  end
end
