defmodule MusicSpit.MixProject do
  use Mix.Project

  def project do
    [
      app: :music_spit,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {MusicSpit.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:finch, "~> 0.9"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.0"},
      {:uuid, "~> 1.1"},
      {:persistent_ets, "~> 0.1.0"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end
end
