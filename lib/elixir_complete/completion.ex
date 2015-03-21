defmodule ElixirComplete.Completion do
  use GenServer
  alias ElixirComplete.Utils, as: Utils
  alias Utils.LineCompleteResult, as: LineCompleteResult
  @builtins [:logger, :iex, :mix, :eex, :ex_unit, :elixir]
  def start_link(args) do
    {:ok, _} = Application.ensure_all_started(:mix)
    load_mixfile(args[:mixfile], args[:root])
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def change_project(mixfile, root) do
    GenServer.call __MODULE__, {:change_project, mixfile, root}
  end

  def line_complete(request) do
    GenServer.call __MODULE__, {:line_complete, request.file,
                                request.line, request.column, request.string}
  end
  def line_complete(file, line, column, string) do
    GenServer.call __MODULE__, {:line_complete, file, line, column, string}
  end

  defp load_mixfile(mixfile, root) do
    modulename = nil
    :ok = File.cd(root)
    #Check to make sure the target mixfile isn't already loaded
    if Mix.ProjectStack.peek[:file] != Path.absname(mixfile, root) do
      try do
        Elixir.Code.load_file mixfile, root
      rescue
        e in Code.LoadError -> IO.puts "couldn't load #{mixfile} in #{root} because #{inspect e}"
      end
    end
    Mix.Project.get.application[:applications] |> load_deps
  end

  defp load_deps(deps) do
    for dep <- deps do
      if dep in @builtins do
        case Utils.ensure_loaded?(dep) do
          true -> IO.puts "loaded #{dep}"
          false -> IO.puts "failed to load #{dep}"
        end
      else
        path = Path.join([Mix.Project.build_path, "lib", to_string(dep), "ebin"])
        case Code.append_path(path) do
          true ->
            if Utils.ensure_loaded?(dep) do
              IO.puts "loaded #{dep}"
            else
              IO.puts "failed to load #{dep}"
            end
          {error, reason} -> IO.puts "failed to append path for #{dep} because #{reason}"
        end
      end
    end
  end

  defp expand(expr) do
    case expr |> String.to_char_list |> Enum.reverse |> IEx.Autocomplete.expand do
      {:yes, '.', []} -> expand("#{expr}.")
      {:yes, hint, []} when length(hint) > 0 -> expand("#{expr}#{hint}")
      {:yes, [], entries} when length(entries) > 0 -> entries
      {:no, [], []} -> []
    end
  end

  defp compile_result(file, line, column, entries) do
    %LineCompleteResult{file: file,
                        line: line,
                        column: column,
                        entries: (for x <- entries, do: to_string x)}
  end

  def handle_call({:line_complete, file, line, column, string}, _from, state) do
    entries = string |> expand
    result = compile_result(file, line, column, entries)
    {:reply, {:ok, result}, state}
  end

  def handle_call({:project_change, mixfile, root}, _from, state) do
    load_mixfile(mixfile, root)
    new_state = List.keyreplace(state, :root, 0, {:root, root})
    new_state = List.keyreplace(new_state, :mixfile, 0, {:mixfile, mixfile})
    {:reply, :ok, new_state}
  end
end
