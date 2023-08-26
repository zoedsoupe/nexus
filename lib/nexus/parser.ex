defmodule Nexus.Parser do
  @moduledoc "Should parse the command and return the value"

  alias Nexus.Command

  defmodule Error do
    defexception [:message]

    @impl true
    def exception(reason) do
      %__MODULE__{message: "Error parsing command: #{reason}"}
    end
  end

  @spec command_from_raw!(Command.t(), binary | list(binary)) :: {term, list(binary)}
  def command_from_raw!(cmd, raw) when is_binary(raw) do
    command_from_raw!(cmd, String.split(raw, ~r/\s/))
  end

  def command_from_raw!(%Command{name: name, type: t}, args) when is_list(args) do
    ns = to_string(name)

    case args do
      [^ns, value | args] -> {string_to!(value, t), args}
      args -> raise "Failed to parse command #{ns} with args #{inspect(args)}"
    end
  end

  defp string_to!(raw, :string), do: raw

  defp string_to!(raw, :integer) do
    case Integer.parse(raw) do
      {int, ""} -> int
      _ -> raise Error, "#{raw} is not a valid integer"
    end
  end

  defp string_to!(raw, :float) do
    case Float.parse(raw) do
      {float, ""} -> float
      _ -> raise Error, "#{raw} is not a valid float"
    end
  end

  # final user should not be used very often
  defp string_to!(raw, :atom) do
    String.to_atom(raw)
  end
end
