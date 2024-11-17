defmodule Nexus.CLI.Help do
  @moduledoc """
  Provides functionality to display help messages based on the CLI AST.
  """

  @doc """
  Displays help information for the given command path.

  If no command path is provided, it displays the root help.
  """
  def display(ast, command_path \\ []) do
    cmd = get_command(ast, command_path)

    if cmd do
      # Build the full command path
      full_command = build_full_command(["file" | command_path])

      # Program description
      IO.puts("#{String.capitalize(full_command)} - #{cmd.description || "No description"}\n")

      # Build usage line
      usage = build_usage_line(full_command, cmd)
      IO.puts("Usage: #{usage}\n")

      # Display subcommands, arguments, and options
      display_subcommands(cmd)
      display_arguments(cmd)
      display_options(cmd)

      # Final note
      if cmd.subcommands != [] do
        IO.puts("Use '#{full_command} [COMMAND] --help' for more information on a command.")
      end
    else
      IO.puts("Command not found")
    end
  end

  ## Helper Functions

  # Builds the full command string from the command path
  defp build_full_command(command_path) do
    Enum.join(command_path, " ")
  end

  # Retrieves the command based on the command path
  defp get_command(ast, command_path) do
    root_cmd = Enum.at(ast, 0)
    get_subcommand(root_cmd, command_path)
  end

  defp get_subcommand(cmd, []), do: cmd

  defp get_subcommand(cmd, [name | rest]) do
    subcmd = Enum.find(cmd.subcommands, &(&1.name == name))

    if subcmd do
      get_subcommand(subcmd, rest)
    else
      nil
    end
  end

  # Builds the usage line for the help output
  defp build_usage_line(full_command, cmd) do
    parts = [full_command]

    # Include options
    parts = if cmd.flags != [], do: parts ++ ["[OPTIONS]"], else: parts

    # Include subcommands
    parts = if cmd.subcommands != [], do: parts ++ ["[COMMAND]"], else: parts

    # Include arguments
    arg_strings =
      Enum.map(cmd.args, fn arg ->
        if arg.required, do: "<#{arg.name}>", else: "[#{arg.name}]"
      end)

    parts = parts ++ arg_strings

    Enum.join(parts, " ")
  end

  # Displays subcommands if any
  defp display_subcommands(cmd) do
    if cmd.subcommands != [] do
      IO.puts("Commands:")

      Enum.each(cmd.subcommands, fn subcmd ->
        IO.puts("  #{subcmd.name}  #{subcmd.description || "No description"}\n")
      end)
    end
  end

  # Displays arguments if any
  defp display_arguments(cmd) do
    if cmd.args != [] do
      IO.puts("Arguments:")

      Enum.each(cmd.args, &display_arg/1)
    end
  end

  defp display_arg(arg) do
    arg_name = if arg.required, do: "<#{arg.name}>", else: "[#{arg.name}]"
    IO.puts("  #{arg_name}\tType: #{format_arg_type(arg.type)}\n")
  end

  # Displays options (flags), including the help option
  defp display_options(cmd) do
    IO.puts("Options:")

    Enum.each(cmd.flags, fn flag ->
      short = if flag.short, do: "-#{flag.short}, ", else: "    "
      type = if flag.type != :boolean, do: " <#{String.upcase(to_string(flag.type))}>", else: ""
      IO.puts("  #{short}--#{flag.name}#{type}\t#{flag.description || "No description"}")
    end)

    # Include help option
    IO.puts("  -h, --help\tPrint help information\n")
  end

  # Formats the argument type for display
  defp format_arg_type({:list, type}), do: "List of #{inspect(type)}"
  defp format_arg_type({:enum, values}), do: "One of #{inspect(values)}"
  defp format_arg_type(type), do: "#{inspect(type)}"
end
