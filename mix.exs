defmodule CaptainFact.Mixfile do
  use Mix.Project

  def project do
    [app: :captain_fact,
     version: "0.4.0",
     elixir: "~> 1.5",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix, :gettext] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     aliases: aliases(),
     deps: deps()]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {CaptainFact, []},
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.3.0", override: true},
      {:phoenix_pubsub, "~> 1.0"},
      {:phoenix_ecto, "~> 3.2"},
      {:phoenix_html, "~> 2.6"},
      {:phoenix_live_reload, "~> 1.0", only: :dev},
      {:postgrex, ">= 0.0.0"},
      {:gettext, "~> 0.11"},
      {:cowboy, "~> 1.0"},
      {:corsica, "~> 0.5"},
      {:comeonin, "~> 3.0"},
      {:ueberauth, github: "CaptainFact/ueberauth", override: true},
      {:ueberauth_identity, "~> 0.2"},
      {:ueberauth_facebook, "~> 0.6"},
      {:guardian, "~> 0.10"},
      {:ecto_enum, "~> 1.0"},
      {:arc, "~> 0.8.0"},
      {:arc_ecto, "~> 0.7.0"},
      {:floki, "~> 0.17.0"},
      {:hashids, "~> 2.0"},
      {:html_entities, "~> 0.3"},
      {:httpoison, "~> 0.11.2"},
      {:poison, "~> 2.2.0"},
      {:csv, "~> 1.4.4"},
      {:quantum, ">= 1.9.2"},
      {:not_qwerty123, "~> 2.1"},
      {:bamboo, "~> 1.0.0-rc.1"},
      {:ex_machina, "~> 2.0", only: [:test, :dev]},
      {:faker, "~> 0.7", only: [:test, :dev]},
      {:bypass, "~> 0.8", only: :test},
      {:distillery, "~> 1.4", runtime: false},
      # Force last version of timex to fix a bug between distillery and Elixir 1.5 both implementing inspect for
      # DateTime. https://github.com/bitwalker/timex/issues/343
      # TODO: Remove when next distillery version comes out
      {:timex, github: "bitwalker/timex", override: true},
   ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    ["ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
     "ecto.reset": ["ecto.drop", "ecto.setup"],
     "test": ["ecto.create --quiet", "ecto.migrate", "test"]]
  end
end