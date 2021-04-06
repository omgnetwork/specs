defmodule Itest.MixProject do
  use Mix.Project

  def project() do
    [
      app: :itest,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock"
    ]
  end

  def application() do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps() do
    [
      # {:ex_plasma, "~> 0.3.0"},
      {:ex_plasma, git: "https://github.com/omgnetwork/ex_plasma", branch: "inomurko/v0.4.0"},
      {:watcher_info_api, in_umbrella: true},
      {:watcher_security_critical_api, in_umbrella: true},
      {:child_chain_api, in_umbrella: true},
      {:eip_55, "~> 0.1"},
      {:ethereumex, "~> 0.6.0"},
      {:telemetry, "~> 0.4.1"},
      {:websockex, "~> 0.4.2"},
      {:ex_abi, "~> 0.5.3"},
      {:ex_rlp, "~> 0.5.3"},
      {:ex_secp256k1, "~> 0.1.2"},
      {:poison, "~> 3.0"},
      {:tesla, "~> 1.3"},
      {:hackney, "~> 1.17.0"},
      {:cabbage, "~> 0.3.0"}
    ]
  end
end
