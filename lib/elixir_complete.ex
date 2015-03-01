defmodule ElixirComplete do
  use Application
  @moduledoc false

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    port = Application.get_env(ElixirComplete, :port)
    children = [
      supervisor(Task.Supervisor, [[name: ElixirComplete.TaskSupervisor]]),
      worker(Task, [ElixirComplete, :listen, [port]])
    ]
    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElixirComplete.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def listen(port) do
    IO.puts "Listening for connections on port #{port}"
    case :gen_tcp.listen(port, [:binary, packet: :line, active: false]) do
      {:ok, socket} -> loop_accept(socket)
      {:error, _reason} -> Kernel.exit(:error)
    end
  end

  def loop_accept(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    Task.Supervisor.start_child(ElixirComplete.TaskSupervisor,
                                fn -> serve(client) end)
    loop_accept(socket)
  end

  def serve(client) do
    {:ok, data} = :gen_tcp.recv(client, 0)
    write_line(client, data)
    serve(client)
  end

  def write_line(socket, line) do
    :ok = :gen_tcp.send(socket, line)
  end
end
