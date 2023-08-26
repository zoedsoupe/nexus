defmodule Nexus.CommandDispatcher do
  @moduledoc false

  alias Nexus.Command
  alias Nexus.Command.Input
  alias Nexus.Parser

  @spec dispatch!(Nexus.command() | binary | list(binary), list(binary)) :: term

  def dispatch!(%Command{} = spec, raw) do
    {value, raw} = Parser.command_from_raw!(spec, raw)
    input = Input.parse!(value, raw)
    spec.module.handle_input(spec.name, input)
  end

  def dispatch!(module, args) when is_binary(args) do
    dispatch!(module, String.split(args, ~r/\s/))
  end

  def dispatch!(module, args) when is_list(args) do
    cmd =
      Enum.find(module.__commands__(), fn %{name: n} ->
        to_string(n) == List.first(args)
      end)

    if cmd do
      dispatch!(cmd, args)
    else
      raise "Command #{hd(args)} not found in #{module}"
    end
  end
end
