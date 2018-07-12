defmodule CaptainFactAtomFeed.Mixfile do
  use Mix.Project

  def project do
    [
      app: :cf_atom_feed,
      version: "0.8.6",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env),
      compilers: Mix.compilers,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {CaptainFactAtomFeed.Application, []},
      extra_applications: [:logger, :runtime_tools, :cowboy, :plug]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [
      # --- Runtime
      {:atomex, "~> 0.2"},
      {:cowboy, "~> 1.0"},
      {:plug, "~> 1.0"},

      # ---- In Umbrella
      {:db, in_umbrella: true}
    ]
  end
end
