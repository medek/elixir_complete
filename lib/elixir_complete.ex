defmodule ElixirComplete do
  use Application
  alias ElixirComplete.Utils.LineCompleteRequest, as: LCR
  alias ElixirComplete.Utils.LineCompleteResult, as: LCRes
  @moduledoc false

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    port = Application.get_env(ElixirComplete, :port)
    root = Application.get_env(ElixirComplete, :root)
    cache = Application.get_env(ElixirComplete, :cache)
    mixfile = Application.get_env(ElixirComplete, :mixfile)

    children = [
      supervisor(Task.Supervisor, [[name: ElixirComplete.TaskSupervisor]]),
      worker(Task, [ElixirComplete, :listen, [port]], id: :listener),
      worker(ElixirComplete.Completion, [[root: root, cache: cache, mixfile: mixfile]])
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
    {:ok, pid} = Task.Supervisor.start_child(ElixirComplete.TaskSupervisor, fn -> serve(client) end)
    IO.puts "Got new client #{inspect pid}"
    loop_accept(socket)
  end

  defp serve(client) do
    case :gen_tcp.recv(client, 0) do
      {:ok, data} -> data |> handle |> write_line(client)
      {:error, reason} ->
        IO.puts "client #{inspect self()} gone, because #{reason}"
        Process.exit(self(), :kill)
    end
    serve(client)
  end

  defp message(data) do
    {status, result} = Poison.encode(data)
    if status != :ok do
      result = ~s({"result": "error", "reason": "poison is poisoned"})
    end
    result
  end

  defp handle(data) do #this needs to be better
    result = ""
    case data |> String.strip |> String.split(" ", parts: 2) do
      ["IsAlive"] ->
        result = message(%{result: :ok})
      ["HaltServer"] ->
        Task.async(fn -> :timer.sleep(1000); System.halt() end)
        result = message(%{result: :ok})
      ["LineComplete", expr] ->
        {status, request} = Poison.decode(expr, as: LCR)
        if status == :ok do
          {:ok, entries} = ElixirComplete.Completion.line_complete(request)
          result = message(%{result: :ok, completion: entries})
        else
          result = message(%{result: status, reason: request})
        end
      _ ->
        result = message(%{result: :error, reason: "Unknown command"})
    end
    result
  end

  defp write_line(line, socket) do
    :ok = :gen_tcp.send(socket, line)
  end
end
