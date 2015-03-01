defmodule ElixirComplete.CLI do
  @moduledoc """
  Entry point for escript built version of ElixirComplete
  """
  def main(args) do
    set_defaults
    status = args |> parse_args |> process_args
    if status == :ok do
      {:ok, pid} = ElixirComplete.start(ElixirComplete, :permenent)
      :timer.sleep(:infinity)
    end
  end
  
  defp set_defaults do
    [port: 63500, cache: false, root: System.cwd()] |> process_args
  end

  defp parse_args(args) do
    options = OptionParser.parse(args, switches: [help: :boolean,
                                                  port: :integer,
                                                  cache: :boolean,
                                                  root: :string],
                                       aliases: [h: :help, s: :server,
                                                 p: :port])
    case options do
      {[help: true], _, _} -> {:help, true}
      {args, _, []} -> args
      _ -> {:help, true}
    end
  end

  defp process_args({:help, true}) do
    IO.puts "elixir_complete [--cli] [--server host] [--port port] [--cache] [--root /path/to/project]"
    IO.puts "\t--help -h: display this help message"
    IO.puts "\t--port -p: port for the http server"
    IO.puts "\t--cache: cache partial inputs for faster lookup"
    IO.puts "\t--root: root directory of an elixir project"
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
