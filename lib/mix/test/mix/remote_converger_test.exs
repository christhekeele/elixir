Code.require_file "../test_helper.exs", __DIR__

defmodule Mix.RemoteConvergerTest do
  use MixTest.Case
  use DepsHelpers

  defmodule IdentityRemoteConverger do
    @behaviour Mix.RemoteConverger

    def remote?(_app), do: true

    def converge(deps, lock) do
      Process.put(:remote_converger, deps)
      lock
    end

    def deps(_dep, _lock) do
      []
    end
  end

  test "remote converger" do
    deps = [{:deps_repo, "0.1.0", path: "custom/deps_repo"},
            {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo")}]

    with_deps deps, fn ->
      Mix.RemoteConverger.register(IdentityRemoteConverger)

      in_fixture "deps_status", fn ->
        Mix.Tasks.Deps.Get.run([])

        message = "* Getting git_repo (#{fixture_path("git_repo")})"
        assert_received {:mix_shell, :info, [^message]}

        assert Process.get(:remote_converger)
      end
    end
  after
    Mix.RemoteConverger.register(nil)
  end

  test "pass dependencies to remote converger in defined order" do
    deps = [
      {:ok,         "0.1.0", path: "deps/ok"},
      {:invalidvsn, "0.2.0", path: "deps/invalidvsn"},
      {:invalidapp, "0.1.0", path: "deps/invalidapp"},
      {:noappfile,  "0.1.0", path: "deps/noappfile"}
    ]

    with_deps deps, fn ->
      Mix.RemoteConverger.register(IdentityRemoteConverger)

      in_fixture "deps_status", fn ->
        Mix.Tasks.Deps.Get.run([])

        deps = Process.get(:remote_converger) |> Enum.map(& &1.app)
        assert deps == [:ok, :invalidvsn, :invalidapp, :noappfile]
      end
    end
  after
    Mix.RemoteConverger.register(nil)
  end

  defmodule RaiseRemoteConverger do
    @behaviour Mix.RemoteConverger

    def remote?(_app), do: false

    def converge(_deps, lock) do
      Process.put(:remote_converger, true)
      lock
    end

    def deps(_dep, _lock) do
      []
    end
  end

  test "remote converger is not invoked if deps diverge" do
    deps = [{:deps_repo, "0.1.0", path: "custom/deps_repo"},
            {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), only: :test}]

    with_deps deps, fn ->
      Mix.RemoteConverger.register(RaiseRemoteConverger)

      in_fixture "deps_status", fn ->
        assert_raise Mix.Error, fn ->
          Mix.Tasks.Deps.Get.run([])
        end

        assert_received {:mix_shell, :error, ["Dependencies have diverged:"]}
        refute Process.get(:remote_converger)
      end
    end
  after
    Mix.RemoteConverger.register(nil)
  end

end
