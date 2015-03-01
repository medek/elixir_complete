defmodule ElixirComplete.Mixfile do
  use Mix.Project

  def project do
    [app: :elixir_complete,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps,
     escript: escript]
  end

  def application do
    [applications: [:logger, :poison],
     mod: {ElixirComplete, []}]
  end


  defp escript do
    [
      main_module: ElixirComplete.CLI,
      app: nil
    ]
  end

  defp deps do
    [
      {:poison, "~> 1.3.0"},
      {:ex_doc, github: "elixir-lang/ex_doc"}
    ]
  end
end
