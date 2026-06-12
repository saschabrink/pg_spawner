defmodule PgSpawner.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/saschabrink/pg_spawner"

  def project do
    [
      app: :pg_spawner,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: description(),
      package: package(),
      name: "PgSpawner",
      source_url: @source_url,
      docs: [
        main: "PgSpawner",
        source_ref: "v#{@version}",
        extras: ["CHANGELOG.md"],
        skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
      ]
    ]
  end

  def application do
    [extra_applications: [:logger], mod: {PgSpawner.Application, []}]
  end

  def cli do
    [preferred_envs: [precommit: :test]]
  end

  defp aliases do
    [
      precommit: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "test"
      ]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Zero-config local Postgres for Elixir. Add the dep, Postgres boots with your app — auto-initdb, no PID files, no stale processes."
  end

  defp package do
    [
      maintainers: ["Sascha Brink"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "https://hexdocs.pm/pg_spawner/changelog.html"
      },
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end
end
