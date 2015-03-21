defmodule ElixirComplete.CLI do
  @moduledoc """
  Entry point for escript built version of ElixirComplete
  """
  def main(args) do
    status = args |> parse_args |> process_args
    if status == :ok do
      {:ok, _} = ElixirComplete.start(ElixirComplete, :permenent)
      :timer.sleep(:infinity)
    end
  end
  
  defp get_defaults do
    [port: 63500, cache: false, root: System.cwd(),
     mixfile: "mix.exs", suicide_seconds: 1000]
  end

  defp parse_args(args) do
    options = OptionParser.parse(args, switches: [help: :boolean,
                                                  port: :integer,
                                                  cache: :boolean,
                                                  root: :string,
                                                  mixfile: :string,
                                                  suicide_seconds: :integer],
                                       aliases: [h: :help, s: :server,
                                                 p: :port])
    case options do
      {[help: true], _, _} -> {:help, true}
      {[], _, []} -> get_defaults()
      {args, _, []} -> args
      _ -> {:help, true}
    end
  end

  defp process_args({:help, true}) do
    IO.puts "elixir_complete [--port port] [--cache] [--root /path/to/project] [--mixfile mix.exs] [--suicide-seconds 1000]"
    IO.puts "\t--help -h: display this help message"
    IO.puts "\t--port -p: port for the http server"
    IO.puts "\t--cache: cache partial inputs for faster lookup"
    IO.puts "\t--root: root directory of an elixir project"
    IO.puts "\t--mixfile: the mixfile to look for in the project root"
    IO.puts "\t--suicide-seconds: how much idle time before the server halts"
    Kernel.exit(:normal)
  end
  defp process_args({name, value}) do
    Application.put_env(ElixirComplete, name, value, [peristent: true])
    :ok
  end
  defp process_args([h|t]) do
    unless t == [], do: process_args(t)
    process_args(h)
  end
end
