defmodule Nexus.CommandDispatcher do
  @moduledoc false

  alias Nexus.Command
  alias Nexus.Parser

  @spec dispatch!(Nexus.command() | module, binary) :: term

  def dispatch!(%Command{} = spec, raw) do
    input = Parser.run!(raw, spec)

    case {spec.type, input.value} do
      {:null, nil} ->
        :ok = spec.module.handle_input(spec.name)

      _ ->
        :ok = spec.module.handle_input(spec.name, input)
    end
  end

  def dispatch!(module, raw) when is_binary(raw) do
    commands = module.__commands__()
    maybe_spec = Enum.reduce_while(commands, nil, &try_parse_command_name(&1, &2, raw))

    case maybe_spec do
      %Command{} = spec -> dispatch!(spec, raw)
      nil -> raise "Failed to parse command #{inspect(raw)}"
    end
  end

  defp try_parse_command_name(spec, acc, raw) do
    alias Nexus.Parser.DSL

    case DSL.literal(raw, spec.name) do
      {:ok, _} -> {:halt, spec}
      {:error, _} -> {:cont, acc}
    end
  end
end
