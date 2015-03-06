defmodule ElixirComplete.Completion do
  use GenServer
  alias ElixirComplete.Utils.LineCompleteRequest, as: LineCompleteRequest
  alias ElixirComplete.Utils.LineCompleteResult, as: LineCompleteResult

  def start_link  do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def line_complete(data) do
    GenServer.call __MODULE__, {:line_complete, data}
  end
  
  defp complete_line(arg) do
    if String.starts_with?(arg.string, "ElixirComplete") do #we're not here!
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
                        entries: entries}
  end

  def handle_call({:line_complete, data}, _from, _state) do
    {:ok, request} = Poison.decode(data, as: LineCompleteRequest)
    {:ok, entries} = complete_line(request)
    {:ok, result} = Poison.encode(entries)
    {:reply, result, _state}
  end

  def handle_call({:add_buffer, data}, _from, _state) do
  end

  def handle_call({:rm_buffer, data}, _from, _state) do
  end
end
