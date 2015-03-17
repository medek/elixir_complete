defmodule ElixirComplete.Completion do
  use GenServer
  alias ElixirComplete.Utils.LineCompleteRequest, as: LineCompleteRequest
  alias ElixirComplete.Utils.LineCompleteResult, as: LineCompleteResult
  alias ElixirComplete.Utils, as: Utils
  @builtins [:logger, :iex, :mix, :eex, :ex_unit, :elixir]
  def start_link(args) do
    {:ok, _} = Application.ensure_all_started(:mix)
    state = List.keyreplace args, :blacklist, 0, load_mixfile(args[:mixfile], args[:root], args[:blacklist])
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def change_project(mixfile, root) do
    GenServer.call __MODULE__, {:change_project, mixfile, root}
  end
  def line_complete(data) do
    GenServer.call __MODULE__, {:line_complete, data}
  end

  defp load_mixfile(mixfile, root, bl) do
    blacklist = bl ++ ["ElixirComplete"]
    modulename = nil
    #Check to make sure the target mixfile isn't already loaded
    if Mix.ProjectStack.peek[:file] != Path.absname(mixfile, root) do
      try do
        module = Elixir.Code.load_file mixfile, root
        {modulename,_} = List.first(module)

        if Module.split(modulename) |> List.first == "ElixirComplete" or
           :elixir_complete in Mix.Project.get.application[:applications] do
             blacklist = List.delete(blacklist, "ElixirComplete")
        end
        Mix.Project.get.application[:applications] |> load_deps
      rescue
        e in Code.LoadError -> IO.puts "couldn't load #{mixfile} in #{root} because #{inspect e}"
      end
    end
    {:blacklist, blacklist}
  end

  defp load_deps(deps) do
    for dep <- deps do
      if dep in @builtins do
        case Code.ensure_loaded?(Utils.atom_to_module(dep)) do
          true -> IO.puts "loaded #{dep}"
          false -> IO.puts "failed to load #{dep}"
        end
      else
        path = Mix.Project.build_path <> "/lib/" <> to_string(dep) <> "/ebin"
        case Code.append_path(path) do
          true ->
            if Code.ensure_loaded?(Utils.atom_to_module(dep)) do
              IO.puts "loaded #{dep}"
            else
              IO.puts "failed to load #{dep}"
            end
          {error, reason} -> IO.puts "failed to append path for #{dep} because #{reason}"
        end
      end
    end
  end

  defp complete_line(arg, blacklist) do
    #TODO: currently only handles top level blacklisting
    #      things like Module1.Module2 fail to block
    if (String.split(arg.string, ".") |> List.first) in blacklist do #we're not here!
      {:ok, compile_result(arg, [])}
    else
      entries = arg.string |> expand
      {:ok, compile_result(arg, entries)}
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

  defp compile_result(arg, entries) do
    %LineCompleteResult{file: arg.file,
                        line: arg.line,
                        column: arg.column,
                        entries: (for x <- entries, do: to_string x)}
  end

  def handle_call({:line_complete, data}, _from, state) do
    {:ok, request} = Poison.decode(data, as: LineCompleteRequest)
    {:ok, entries} = complete_line(request, state[:blacklist])
    {:ok, result} = Poison.encode(entries)
    {:reply, result, state}
  end

  def handle_call({:project_change, mixfile, root}, _from, state) do
    blacklist = load_mixfile(mixfile, root, List.delete(state[:blacklist], "ElixirComplete"))
    new_state = List.keyreplace(state, :blacklist, 0, blacklist)
    {:reply, :ok, new_state}
  end

  def handle_call({:add_buffer, data}, _from, _state) do
  end

  def handle_call({:rm_buffer, data}, _from, _state) do
  end

  def handle_call({:add_blacklist, data}, _from, state) do
  end

  def handle_call({:rm_blacklist, data}, _from, state) do
  end
end
