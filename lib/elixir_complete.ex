defmodule ElixirComplete do
  use Application
  @moduledoc false
  
  def main(args) do
    status = args |> parse_args |> process_args
    if status == :ok do
      IO.puts "Starting ElixirComplete"
      start(ElixirComplete, :permanent)
    end
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

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    children = [
      supervisor(Task.Supervisor, [[name: ElixirComplete.TaskSupervisor]]),
      worker(Task, [ElixirComplete, :listen, [Application.get_env(ElixirComplete, :port)]])
    ]
    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElixirComplete.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def listen(port) do
    case :gen_tcp.listen(port, [:binary, packet: :line, active: false]) do
      {:ok, socket} -> loop_accept(socket)
      {:error, _reason} -> :init.stop
    end
  end

  def loop_accept(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    Task.Supervisor.start_child(ElixirComplete.TaskSupervisor,
                                fn -> serve(client) end)
    loop_accept(socket)
  end

  def serve(client) do
    #TODO handle commands and whatnot
    serve(client)
  end
end
