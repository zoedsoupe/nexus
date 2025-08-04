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
    case find_active_root_flag(cli.root_flags, result.flags) do
      nil -> dispatch(cli, put_in(result, [:flags, :help], true))
      flag_name -> dispatch_root_flag(cli, flag_name, result)
    end
  end

  def dispatch(%CLI{} = cli, %{args: args, flags: flags, command: command}) when map_size(args) == 1 do
    single =
      case Map.values(args) do
        [value] -> value
        [] -> nil
        [first | _rest] -> first
      end

    input = %Input{flags: flags, value: single}

    try do
      case command do
        [root] -> cli.handler.handle_input(root, input)
        path -> cli.handler.handle_input(path, input)
      end
    rescue
      e in [UndefinedFunctionError] ->
        log_handler_error(e, cli, command, "Handler function not defined", __STACKTRACE__)
        {:error, {1, "Command '#{format_command(command)}' is not implemented"}}

      e in [FunctionClauseError] ->
        log_handler_error(e, cli, command, "Invalid arguments for handler", __STACKTRACE__)
        {:error, {1, "Invalid arguments for command '#{format_command(command)}'"}}

      e in [ArgumentError] ->
        log_handler_error(e, cli, command, "Invalid argument", __STACKTRACE__)
        {:error, {1, "Invalid argument: #{Exception.message(e)}"}}

      exception ->
        log_handler_error(exception, cli, command, "Unexpected error in handler", __STACKTRACE__)
        {:error, {1, "An error occurred while executing '#{format_command(command)}'"}}
    end
  end

  def dispatch(%CLI{} = cli, %{args: args, flags: flags, command: command}) do
    input = %Input{args: args, flags: flags}

    try do
      case command do
        [root] -> cli.handler.handle_input(root, input)
        path -> cli.handler.handle_input(path, input)
      end
    rescue
      e in [UndefinedFunctionError] ->
        log_handler_error(e, cli, command, "Handler function not defined", __STACKTRACE__)
        {:error, {1, "Command '#{format_command(command)}' is not implemented"}}

      e in [FunctionClauseError] ->
        log_handler_error(e, cli, command, "Invalid arguments for handler", __STACKTRACE__)
        {:error, {1, "Invalid arguments for command '#{format_command(command)}'"}}

      e in [ArgumentError] ->
        log_handler_error(e, cli, command, "Invalid argument", __STACKTRACE__)
        {:error, {1, "Invalid argument: #{Exception.message(e)}"}}

      exception ->
        log_handler_error(exception, cli, command, "Unexpected error in handler", __STACKTRACE__)
        {:error, {1, "An error occurred while executing '#{format_command(command)}'"}}
    end
  end

  defp log_handler_error(exception, cli, command, context, stack) do
    require Logger

    Logger.error([
      "CLI Handler Error in #{cli.handler} for command '#{format_command(command)}': ",
      context,
      "\nException: #{Exception.format(:error, exception, stack)}"
    ])
  end

  defp format_command([single]), do: to_string(single)
  defp format_command(path) when is_list(path), do: Enum.join(path, " ")

  defp find_active_root_flag(root_flags, flags) do
    Enum.find_value(root_flags, fn flag ->
      if Map.get(flags, flag.name, false) == true, do: flag.name
    end)
  end

  defp dispatch_root_flag(cli, flag_name, result) do
    input = %Input{flags: result.flags, args: result.args}

    try do
      cli.handler.handle_input(flag_name, input)
    rescue
      e in [UndefinedFunctionError] ->
        log_handler_error(e, cli, [flag_name], "Handler function not defined", __STACKTRACE__)
        {:error, {1, "Root flag '#{flag_name}' is not implemented"}}

      e in [FunctionClauseError] ->
        log_handler_error(e, cli, [flag_name], "Invalid arguments for handler", __STACKTRACE__)
        {:error, {1, "Invalid arguments for root flag '#{flag_name}'"}}

      e in [ArgumentError] ->
        log_handler_error(e, cli, [flag_name], "Invalid argument", __STACKTRACE__)
        {:error, {1, "Invalid argument: #{Exception.message(e)}"}}

      exception ->
        log_handler_error(exception, cli, [flag_name], "Unexpected error in handler", __STACKTRACE__)
        {:error, {1, "An error occurred while executing root flag '#{flag_name}'"}}
    end
  end
end
