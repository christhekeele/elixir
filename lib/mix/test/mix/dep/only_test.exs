Code.require_file "../../test_helper.exs", __DIR__

defmodule Mix.Dep.OnlyTest do
  use MixTest.Case
  use DepsHelpers

  test "only extract deps matching environment" do
    with_deps [{:foo, github: "elixir-lang/foo"},
               {:bar, github: "elixir-lang/bar", only: :other_env}], fn ->
      in_fixture "deps_status", fn ->
        deps = Mix.Dep.loaded([env: :other_env])
        assert length(deps) == 2

        deps = Mix.Dep.loaded([])
        assert length(deps) == 2

        assert [dep] = Mix.Dep.loaded([env: :prod])
        assert dep.app == :foo
      end
    end
  end

  test "only fetch parent deps matching specified env" do
    with_deps [{:only, github: "elixir-lang/only", only: [:dev]}], fn ->
      in_fixture "deps_status", fn ->
        Mix.Tasks.Deps.Get.run(["--only", "prod"])
        refute_received {:mix_shell, :info, ["* Getting" <> _]}

        assert_raise Mix.Error, "Can't continue due to errors on dependencies", fn ->
          Mix.Tasks.Deps.Check.run([])
        end

        Mix.ProjectStack.clear_cache()
        Mix.env(:prod)
        Mix.Tasks.Deps.Check.run([])
      end
    end
  end

  test "nested deps selects only prod dependencies" do
    Process.put(:custom_deps_git_repo_opts, [only: :test])
    deps = [{:deps_repo, "0.1.0", path: "custom/deps_repo"}]

    with_deps deps, fn ->
      in_fixture "deps_status", fn ->
        loaded = Mix.Dep.loaded([])
        assert [:deps_repo] = Enum.map(loaded, &(&1.app))

        loaded = Mix.Dep.loaded([env: :test])
        assert [:deps_repo] = Enum.map(loaded, &(&1.app))
      end
    end
  end

  test "nested deps on only matching" do
    # deps_repo wants git_repo for test, git_repo is restricted to only test
    # We assert the dependencies match as expected, happens in umbrella apps
    Process.put(:custom_deps_git_repo_opts, [only: :test])

    # We need to pass env: :test so the child dependency is loaded
    # in the first place (otherwise only :prod deps are loaded)
    deps = [{:deps_repo, "0.1.0", path: "custom/deps_repo", env: :test},
            {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), only: :test}]

    with_deps deps, fn ->
      in_fixture "deps_status", fn ->
        loaded = Mix.Dep.loaded([])
        assert [:git_repo, :deps_repo] = Enum.map(loaded, &(&1.app))
        assert [unavailable: _, noappfile: _] = Enum.map(loaded, &(&1.status))

        loaded = Mix.Dep.loaded([env: :dev])
        assert [:deps_repo] = Enum.map(loaded, &(&1.app))
        assert [noappfile: _] = Enum.map(loaded, &(&1.status))

        loaded = Mix.Dep.loaded([env: :test])
        assert [:git_repo, :deps_repo] = Enum.map(loaded, &(&1.app))
        assert [unavailable: _, noappfile: _] = Enum.map(loaded, &(&1.status))
      end
    end
  end

  test "nested deps on only conflict" do
    # deps_repo wants all git_repo, git_repo is restricted to only test
    deps = [{:deps_repo, "0.1.0", path: "custom/deps_repo"},
            {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), only: :test}]

    with_deps deps, fn ->
      in_fixture "deps_status", fn ->
        loaded = Mix.Dep.loaded([])
        assert [:git_repo, :deps_repo] = Enum.map(loaded, &(&1.app))
        assert [divergedonly: _, noappfile: _] = Enum.map(loaded, &(&1.status))

        loaded = Mix.Dep.loaded([env: :dev])
        assert [:git_repo, :deps_repo] = Enum.map(loaded, &(&1.app))
        assert [divergedonly: _, noappfile: _] = Enum.map(loaded, &(&1.status))

        loaded = Mix.Dep.loaded([env: :test])
        assert [:git_repo, :deps_repo] = Enum.map(loaded, &(&1.app))
        assert [divergedonly: _, noappfile: _] = Enum.map(loaded, &(&1.status))

        Mix.Tasks.Deps.run([])
        assert_received {:mix_shell, :info, ["* git_repo" <> _]}
        assert_received {:mix_shell, :info, [msg]}
        assert msg =~ "Remove the :only restriction from your dep"
      end
    end
  end

  test "nested deps on only conflict does not happen with optional deps" do
    Process.put(:custom_deps_git_repo_opts, [optional: true])

    # deps_repo wants all git_repo, git_repo is restricted to only test
    deps = [{:deps_repo, "0.1.0", path: "custom/deps_repo"},
            {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), only: :test}]

    with_deps deps, fn ->
      in_fixture "deps_status", fn ->
        loaded = Mix.Dep.loaded([])
        assert [:git_repo, :deps_repo] = Enum.map(loaded, &(&1.app))
        assert [unavailable: _, noappfile: _] = Enum.map(loaded, &(&1.status))

        loaded = Mix.Dep.loaded([env: :dev])
        assert [:deps_repo] = Enum.map(loaded, &(&1.app))
        assert [noappfile: _] = Enum.map(loaded, &(&1.status))

        loaded = Mix.Dep.loaded([env: :test])
        assert [:git_repo, :deps_repo] = Enum.map(loaded, &(&1.app))
        assert [unavailable: _, noappfile: _] = Enum.map(loaded, &(&1.status))
      end
    end
  end

  test "nested deps with valid only subset" do
    # deps_repo wants git_repo for prod, git_repo is restricted to only prod and test
    deps = [{:deps_repo, "0.1.0", path: "custom/deps_repo", only: :prod},
            {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), only: [:prod, :test]}]

    with_deps deps, fn ->
      in_fixture "deps_status", fn ->
        loaded = Mix.Dep.loaded([])
        assert [:git_repo, :deps_repo] = Enum.map(loaded, &(&1.app))
        assert [unavailable: _, noappfile: _] = Enum.map(loaded, &(&1.status))

        loaded = Mix.Dep.loaded([env: :dev])
        assert [] = Enum.map(loaded, &(&1.app))

        loaded = Mix.Dep.loaded([env: :test])
        assert [:git_repo] = Enum.map(loaded, &(&1.app))
        assert [unavailable: _] = Enum.map(loaded, &(&1.status))

        loaded = Mix.Dep.loaded([env: :prod])
        assert [:git_repo, :deps_repo] = Enum.map(loaded, &(&1.app))
        assert [unavailable: _, noappfile: _] = Enum.map(loaded, &(&1.status))
      end
    end
  end

  test "nested deps with invalid only subset" do
    # deps_repo wants git_repo for dev, git_repo is restricted to only test
    deps = [{:deps_repo, "0.1.0", path: "custom/deps_repo", only: :dev},
            {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), only: [:test]}]

    with_deps deps, fn ->
      in_fixture "deps_status", fn ->
        loaded = Mix.Dep.loaded([])
        assert [:git_repo, :deps_repo] = Enum.map(loaded, &(&1.app))
        assert [divergedonly: _, noappfile: _] = Enum.map(loaded, &(&1.status))

        loaded = Mix.Dep.loaded([env: :dev])
        assert [:git_repo, :deps_repo] = Enum.map(loaded, &(&1.app))
        assert [divergedonly: _, noappfile: _] = Enum.map(loaded, &(&1.status))

        loaded = Mix.Dep.loaded([env: :test])
        assert [:git_repo] = Enum.map(loaded, &(&1.app))
        assert [unavailable: _] = Enum.map(loaded, &(&1.status))

        Mix.Tasks.Deps.run([])
        assert_received {:mix_shell, :info, ["* git_repo" <> _]}
        assert_received {:mix_shell, :info, [msg]}
        assert msg =~ "Ensure the parent dependency specifies a superset of the child one"
      end
    end
  end

  test "nested deps with valid only in both parent and child" do
    Process.put(:custom_deps_git_repo_opts, [only: :test])

    # deps_repo has environment set to test so it loads the deps_git_repo set to test too
    deps = [{:deps_repo, "0.1.0", path: "custom/deps_repo", env: :test, only: [:dev, :test]},
            {:git_repo, "0.1.0", git: MixTest.Case.fixture_path("git_repo"), only: :test}]

    with_deps deps, fn ->
      in_fixture "deps_status", fn ->
        loaded = Mix.Dep.loaded([])
        assert [:git_repo, :deps_repo] = Enum.map(loaded, &(&1.app))
        assert [unavailable: _, noappfile: _] = Enum.map(loaded, &(&1.status))

        loaded = Mix.Dep.loaded([env: :dev])
        assert [:deps_repo] = Enum.map(loaded, &(&1.app))
        assert [noappfile: _] = Enum.map(loaded, &(&1.status))

        loaded = Mix.Dep.loaded([env: :test])
        assert [:git_repo, :deps_repo] = Enum.map(loaded, &(&1.app))
        assert [unavailable: _, noappfile: _] = Enum.map(loaded, &(&1.status))

        loaded = Mix.Dep.loaded([env: :prod])
        assert [] = Enum.map(loaded, &(&1.app))
      end
    end
  end

  test "nested deps converge and diverge when only is not in_upper" do
    loaded_only = fn deps ->
      with_deps deps, fn ->
        in_fixture "deps_status", fn ->
          File.mkdir_p! "custom/other_repo"
          File.write! "custom/other_repo/mix.exs", """
          defmodule OtherRepo do
            use Mix.Project

            def project do
              [app: :deps_repo,
               version: "0.1.0",
               deps: [{:git_repo, "0.1.0", git: MixTest.Case.fixture_path("git_repo")}]]
            end
          end
          """

          Mix.ProjectStack.clear_cache
          loaded = Mix.Dep.loaded([])
          assert [:git_repo, _, _] = Enum.map(loaded, &(&1.app))
          hd(loaded).opts[:only]
        end
      end
    end

    deps = [{:deps_repo, "0.1.0", path: "custom/deps_repo", only: :prod},
            {:other_repo, "0.1.0", path: "custom/other_repo", only: :test}]
    assert loaded_only.(deps) == [:test, :prod]

    deps = [{:deps_repo, "0.1.0", path: "custom/deps_repo"},
            {:other_repo, "0.1.0", path: "custom/other_repo", only: :test}]
    refute loaded_only.(deps)

    deps = [{:deps_repo, "0.1.0", path: "custom/deps_repo", only: :prod},
            {:other_repo, "0.1.0", path: "custom/other_repo"}]
    refute loaded_only.(deps)

    deps = [{:deps_repo, "0.1.0", path: "custom/deps_repo"},
            {:other_repo, "0.1.0", path: "custom/other_repo"}]
    refute loaded_only.(deps)

    Process.put(:custom_deps_git_repo_opts, [optional: true])
    deps = [{:deps_repo, "0.1.0", path: "custom/deps_repo", only: :prod},
            {:other_repo, "0.1.0", path: "custom/other_repo", only: :test}]
    assert loaded_only.(deps) == :test
  end
end
