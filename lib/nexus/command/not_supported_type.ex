defmodule Nexus.Command.NotSupportedType do
  defexception [:message]

  @impl true
  def exception(type) do
    %__MODULE__{message: "Command type not supported yet: #{inspect(type)}"}
  end
end
