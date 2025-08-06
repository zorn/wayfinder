defmodule Wayfinder.MixProject do
  use Mix.Project

  def project do
    [
      app: :wayfinder,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],

      # Allow the `mix check` (which will run `dialyzer` under a `:test`
      # `MIX_ENV` to see `ex_unit` modules.)
      dialyzer: [
        plt_add_apps: [:ex_unit]
      ],

      # Docs
      name: "Wayfinder",
      source_url: "https://github.com/zorn/wayfinder",
      # homepage_url: "https://example.com",
      docs: [
        # The main page in the docs
        main: "Wayfinder",
        extras: ["README.md"]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Wayfinder.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # For TDD.
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},

      # For password hashing.
      {:argon2_elixir, "~> 4.0"},

      # For docs
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true},

      # For code logic style and enforcement.
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},

      # For security scans.
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},

      # Uncategorized
      {:phoenix, "~> 1.8.0-rc.4", override: true},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0-rc.3"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind wayfinder", "esbuild wayfinder"],
      "assets.deploy": [
        "tailwind wayfinder --minify",
        "esbuild wayfinder --minify",
        "phx.digest"
      ],
      # A single task simulating the CI checks that will run.
      check: ["credo --strict", "dialyzer", "sobelow", "test"]
    ]
  end

  def cli do
    # Using the MIX_ENV of `:test` for the check alias is required for testing.
    # This does mean that dialyzer and sobelow will run in test mode which is
    # not what you typically see when running `mix dialyzer` or `mix sobelow`.
    [preferred_envs: [check: :test]]
  end
end
