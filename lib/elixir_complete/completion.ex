defmodule ElixirComplete.Completion do
  use GenServer
  alias ElixirComplete.Utils.LineCompleteRequest, as: LineCompleteRequest
  alias ElixirComplete.Utils.LineCompleteResult, as: LineCompleteResult

  def start_link(args) do
    {:ok, _} = Application.ensure_all_started(:mix)
    state = List.keyreplace args, :blacklist, 0, load_mixfile(args[:mixfile], args[:root], args[:blacklist])
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def line_complete(data) do
    GenServer.call __MODULE__, {:line_complete, data}
  end

  defp load_mixfile(mixfile, root, bl) do
    blacklist = bl ++ ["ElixirComplete"]
    modulename = nil
    #Check to make sure the target mixfile isn't already loaded
    if Mix.ProjectStack.peek[:file] != Path.absname(mixfile, root) do
      module = Elixir.Code.load_file mixfile, root
      {modulename,_} = List.first(module)

      if Module.split(modulename) |> List.first == "ElixirComplete" or
         :elixir_complete in Mix.Project.get.application[:applications] do
           blacklist = List.delete(blacklist, "ElixirComplete")
      end
    end
    Mix.Project.get.application[:applications] |> strip_builtin |> load_deps
    {:blacklist, blacklist}
  end
  #Remove built in stuff like :logger
  defp strip_builtin(deps) do
    Enum.filter(deps,
      fn(x) ->
        not x in [:logger, :iex, :mix, :eex, :ex_unit, :elixir]
      end)
  end

  defp load_deps(deps) do
    #Should I try to get and compile deps if this fails?
    for dep <- deps do
      path = Mix.Project.build_path <> "/lib/" <> to_string(dep) <> "/ebin"
      case Code.append_path(path) do
        true ->
          if Code.ensure_loaded?(Module.concat([Mix.Utils.camelize(to_string dep)])) do
            IO.puts "loaded #{dep}"
          else
            IO.puts "fuck! something goofed on #{dep} loading"
          end
        {error, reason} -> IO.puts "failed to load #{dep} because #{reason}"
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

  def handle_call({:add_buffer, data}, _from, _state) do
  end

  def handle_call({:rm_buffer, data}, _from, _state) do
  end

  def handle_call({:add_blacklist, data}, _from, state) do
  end

  def handle_call({:rm_blacklist, data}, _from, state) do
  end
end
