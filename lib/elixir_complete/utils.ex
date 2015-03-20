defmodule ElixirComplete.Utils do
  @moduledoc """
  Utility functions and structures
  """

  defmodule LineCompleteRequest do
    @moduledoc """
    Structure of the line completion request.
    #{:file} - filename of the file to do the request in
    #{:line} - line number, starts at 1
    #{:column} - column number, starts at 1
    #{:string} - the text to complete
    #{:buffer} - file currently being edited if no caching is used
    """
    defstruct [:file, :line, :column, :string, :buffer]
  end

  defmodule LineCompleteResult do
    defstruct [:file, :line, :column, :entries]
  end 
  
  defmodule AddBufferRequest do
    @moduledoc """
    Structure of the add buffer request. This is used to pass in
    files as they are written. Also useful when you start writing a
    fresh file and there's nothing to read from disk.
    #{:file} - filename of the file to do the request in
    #{:line} - line number, starts at 1
    #{:column} - column number, starts at 1
    #{:buffer} - string to add at location #{:line}:#{:column}
    """
    defstruct [:file, :line, :column, :buffer]
  end

  defmodule RemoveBufferRequest do
    @moduledoc """
    Structure for removing from the buffer. Same as AddBufferRequest except
    buffer is instead a char count.
    #{:file} - filename of the file to do the request in
    #{:line} - line number, starts at 1
    #{:column} - column number, starts at 1
    #{:count} - string to add at location #{:line}:#{:column}
    """
    defstruct [:file, :line, :column, :count]
  end

  def ensure_loaded?(atom) do
    case Code.ensure_loaded?(atom_to_module(atom)) do
      true -> true
      false ->
        Code.ensure_loaded?(atom)
    end
  end

  def atom_to_module(atom) do
    if atom == :iex do
      Module.concat ["IEx"] #...
    else
      Module.concat([Mix.Utils.camelize(to_string atom)])
    end
  end
end

