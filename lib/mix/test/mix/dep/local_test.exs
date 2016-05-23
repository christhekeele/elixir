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

  test "deps not in local config are unchanged" do
    local = %{}
    dep = %Mix.Dep{app: :name}
    assert dep == Mix.Dep.check_local(dep, local)
  end

  test "deps disabled in local config are unchanged" do
    local = %{
      foo: {:disabled, "bar"},
    }

    git_dep = %Mix.Dep{app: :foo, scm: Mix.SCM.Git}
    assert git_dep == Mix.Dep.check_local(git_dep, local)

    path_dep = %Mix.Dep{app: :foo, scm: Mix.SCM.Path, opts: [path: "foo"]}
    assert path_dep == Mix.Dep.check_local(path_dep, local)
  end

  test "non-git deps enabled in local config are unchanged" do
    local = %{
      foo: {:enabled, "bar"},
    }

    path_dep = %Mix.Dep{app: :foo, scm: Mix.SCM.Path, opts: [path: "foo"]}
    localized_path_dep = Mix.Dep.check_local(path_dep, local)
    assert %Mix.Dep{app: :foo, scm: Mix.SCM.Path} = localized_path_dep
    assert {:path, "foo"} in path_dep.opts
  end

  test "git deps enabled in local config become path deps" do
    local = %{
      foo: {:enabled, "bar"},
    }

    git_dep = %Mix.Dep{app: :foo, scm: Mix.SCM.Git}
    localized_git_dep = Mix.Dep.check_local(git_dep, local)
    assert %Mix.Dep{app: :foo, scm: Mix.SCM.Path} = localized_git_dep
    assert {:path, "bar"} in localized_git_dep.opts
  end
end
