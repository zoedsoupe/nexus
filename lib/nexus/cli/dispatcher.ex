defmodule Nexus.CLI.Dispatcher do
  @moduledoc """
  Dispatches parsed CLI commands to the appropriate handler functions.
  """

  alias Nexus.CLI
  alias Nexus.CLI.Help
  alias Nexus.CLI.Input

  alias Nexus.Parser

  @doc """
  Dispatches the parsed command to the corresponding handler.

  - `module` is the module where the handler functions are defined.
  - `parsed` is the result from `Nexus.Parser.parse_ast/2`.
  """
  @spec dispatch(CLI.t(), Parser.result()) :: :ok | {:error, CLI.error()}
  def dispatch(%CLI{} = cli, %{flags: %{help: true}} = result) do
    Help.display(cli, result.command)

    :ok
  end

  def dispatch(%CLI{} = cli, %{command: []} = result) do
    dispatch(cli, put_in(result, [:flags, :help], true))
  end

  def dispatch(%CLI{} = cli, %{args: args, flags: flags, command: command})
      when map_size(args) == 1 do
    single = hd(Map.values(args))
    input = %Input{flags: flags, value: single}

    case command do
      [root] -> cli.handler.handle_input(root, input)
      path -> cli.handler.handle_input(path, input)
    end
  rescue
    _ -> fail_with_help(cli, command)
  end

  def dispatch(%CLI{} = cli, %{args: args, flags: flags, command: command}) do
    input = %Input{args: args, flags: flags}

    case command do
      [root] -> cli.handler.handle_input(root, input)
      path -> cli.handler.handle_input(path, input)
    end
  rescue
    _ -> fail_with_help(cli, command)
  end

  defp fail_with_help(cli, cmd) do
    Help.display(cli, cmd)
    {:error, {1, nil}}
  end
end
