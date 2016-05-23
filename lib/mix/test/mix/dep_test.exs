Code.require_file "../test_helper.exs", __DIR__

defmodule Mix.DepTest do
  use MixTest.Case
  use DepsHelpers

  test "extracts all dependencies from the given project" do
    Mix.Project.push DepsApp

    in_fixture "deps_status", fn ->
      deps = Mix.Dep.loaded([])
      assert length(deps) == 6
      assert Enum.find deps, &match?(%Mix.Dep{app: :ok, status: {:ok, _}}, &1)
      assert Enum.find deps, &match?(%Mix.Dep{app: :invalidvsn, status: {:invalidvsn, :ok}}, &1)
      assert Enum.find deps, &match?(%Mix.Dep{app: :invalidapp, status: {:invalidapp, _}}, &1)
      assert Enum.find deps, &match?(%Mix.Dep{app: :noappfile, status: {:noappfile, _}}, &1)
      assert Enum.find deps, &match?(%Mix.Dep{app: :uncloned, status: {:unavailable, _}}, &1)
      assert Enum.find deps, &match?(%Mix.Dep{app: :optional, status: {:unavailable, _}}, &1)
    end
  end

  test "extracts all dependencies paths from the given project" do
    Mix.Project.push DepsApp

    in_fixture "deps_status", fn ->
      paths = Mix.Project.deps_paths
      assert map_size(paths) == 6
      assert paths[:ok] =~ "deps/ok"
      assert paths[:uncloned] =~ "deps/uncloned"
    end
  end

  test "fails on invalid dependencies" do
    assert_wrong_dependency [{:ok}]
    assert_wrong_dependency [{:ok, nil}]
    assert_wrong_dependency [{:ok, nil, []}]
  end

  test "use requirements for dependencies" do
    with_deps [{:ok, "~> 0.1", path: "deps/ok"}], fn ->
      in_fixture "deps_status", fn ->
        deps = Mix.Dep.loaded([])
        assert Enum.find deps, &match?(%Mix.Dep{app: :ok, status: {:ok, _}}, &1)
      end
    end
  end

  test "raises when no SCM is specified" do
    with_deps [{:ok, "~> 0.1", not_really: :ok}], fn ->
      in_fixture "deps_status", fn ->
        send self, {:mix_shell_input, :yes?, false}
        msg = "Could not find an SCM for dependency :ok from ProcessDepsApp"
        assert_raise Mix.Error, msg, fn -> Mix.Dep.loaded([]) end
      end
    end
  end

  test "does not set the manager before the dependency was loaded" do
    # It is important to not eagerly set the manager because the dependency
    # needs to be loaded (i.e. available in the filesystem) in order to get
    # the proper manager.
    Mix.Project.push DepsApp

    {_, true, _} =
      Mix.Dep.Converger.converge(false, [], nil, nil, fn dep, acc, lock, _local ->
        assert is_nil(dep.manager)
        {dep, acc or true, lock}
      end)
  end

  test "raises on invalid deps req" do
    with_deps [{:ok, "+- 0.1.0", path: "deps/ok"}], fn ->
      in_fixture "deps_status", fn ->
        assert_raise Mix.Error, ~r"Invalid requirement", fn ->
          Mix.Dep.loaded([])
        end
      end
    end
  end

  test "nested deps come first" do
    with_deps [{:deps_repo, "0.1.0", path: "custom/deps_repo"}], fn ->
      in_fixture "deps_status", fn ->
        assert Enum.map(Mix.Dep.loaded([]), &(&1.app)) == [:git_repo, :deps_repo]
      end
    end
  end

  test "nested optional deps are never added" do
    with_deps [{:deps_repo, "0.1.0", path: "custom/deps_repo"}], fn ->
      in_fixture "deps_status", fn ->
        File.write! "custom/deps_repo/mix.exs", """
        defmodule DepsRepo do
          use Mix.Project

          def project do
            [app: :deps_repo,
             version: "0.1.0",
             deps: [{:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), optional: true}]]
          end
        end
        """

        assert Enum.map(Mix.Dep.loaded([]), &(&1.app)) == [:deps_repo]
      end
    end
  end

  test "nested deps with convergence" do
    deps = [{:deps_repo, "0.1.0", path: "custom/deps_repo"},
            {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo")}]

    with_deps deps, fn ->
      in_fixture "deps_status", fn ->
        assert Enum.map(Mix.Dep.loaded([]), &(&1.app)) == [:git_repo, :deps_repo]
      end
    end
  end

  test "nested deps with convergence and managers" do
    Process.put(:custom_deps_git_repo_opts, [manager: :make])

    deps = [{:deps_repo, "0.1.0", path: "custom/deps_repo", manager: :rebar},
            {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo")}]

    with_deps deps, fn ->
      in_fixture "deps_status", fn ->
        [dep1, dep2] = Mix.Dep.loaded([])
        assert dep1.manager == nil
        assert dep2.manager == :rebar
      end
    end
  end

  test "nested deps with convergence and optional dependencies" do
    deps = [{:deps_repo, "0.1.0", path: "custom/deps_repo"},
            {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo")}]

    with_deps deps, fn ->
      in_fixture "deps_status", fn ->
        File.write! "custom/deps_repo/mix.exs", """
        defmodule DepsRepo do
          use Mix.Project

          def project do
            [app: :deps_repo,
             version: "0.1.0",
             deps: [{:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), optional: true}]]
          end
        end
        """

        assert Enum.map(Mix.Dep.loaded([]), &(&1.app)) == [:git_repo, :deps_repo]
      end
    end
  end

  test "nested deps with optional dependencies and cousin conflict" do
    with_deps [{:deps_repo1, "0.1.0", path: "custom/deps_repo1"},
               {:deps_repo2, "0.1.0", path: "custom/deps_repo2"}], fn ->
      in_fixture "deps_status", fn ->
        File.mkdir_p!("custom/deps_repo1")
        File.write! "custom/deps_repo1/mix.exs", """
        defmodule DepsRepo1 do
          use Mix.Project

          def project do
            [app: :deps_repo1,
             version: "0.1.0",
             deps: [{:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), optional: true}]]
          end
        end
        """

        File.mkdir_p!("custom/deps_repo2")
        File.write! "custom/deps_repo2/mix.exs", """
        defmodule DepsRepo2 do
          use Mix.Project

          def project do
            [app: :deps_repo2,
             version: "0.1.0",
             deps: [{:git_repo, "0.2.0", path: "somewhere"}]]
          end
        end
        """

        Mix.Tasks.Deps.run([])
        assert_received {:mix_shell, :info, ["* git_repo" <> _]}
        assert_received {:mix_shell, :info, [msg]}
        assert msg =~ "different specs were given for the git_repo"
      end
    end
  end
end
