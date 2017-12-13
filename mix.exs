defmodule DefprotocolDialyzerWarn.Mixfile do
  use Mix.Project

  def project, do: [
    app: :defprotocol_dialyzer_warn,
    version: "0.1.0",
    elixir: "~> 1.3",
    start_permanent: Mix.env == :prod,
    deps: deps(),
    dialyzer_warnings: [
      :unmatched_returns,
      :error_handling,
      :race_conditions,
      # :underspecs, # Protocols also generate 8 of these each
      :unknown,
    ],
    # This configuration will ignore the warnings I am receiving:
    # dialyzer_ignore_warnings: [{ :warn_matching, {:_, :_}, {:guard_fail, [:or, '(\'false\',\'false\')']} }]
    aliases: [
      test: ~w[test dialyzer],
    ],
  ]

  def application, do: [
    extra_applications: [:logger]
  ]

  defp deps, do: [
    {:dialyzex, ">= 0.0.0"},

    {:phoenix, "1.3.0"},
    {:plug, "1.4.3"},
    {:poison, "3.1.0"},
  ]

end
