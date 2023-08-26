# credo:disable-for-next-line
defmodule Nexus.FailedCommandParsing do
  defexception [:message]

  @impl true
  def exception(reason) do
    %__MODULE__{message: "Error parsing command: #{reason}"}
  end
end
