defmodule Nexus.CLI.Help do
  @moduledoc """
  Provides functionality to display help messages based on the CLI AST.
  """

  alias Nexus.CLI
  alias Nexus.CLI.Command

  @doc """
  Displays help information for the given command path.

  If no command path is provided, it displays the root help.
  """
  @spec display(CLI.t(), list(atom)) :: :ok
  def display(%CLI{} = cli, command_path \\ []) do
    cmd = get_command(cli, command_path)

    if cmd do
      if function_exported?(cli.handler, :banner, 0) do
        IO.puts(cli.handler.banner() <> "\n")
      end

      # Build usage line
      usage = build_usage_line(cli.name, command_path, cmd)
      IO.puts("Usage: #{usage}\n")

      # Display description of the command
      if cmd.description do
        IO.puts("#{cmd.description}\n")
      end

      # Display subcommands, arguments, and options
      display_subcommands(cmd)
      display_arguments(cmd)
      display_options(cmd)

      # Final note
      if cmd.subcommands != [] do
        IO.puts("\nUse '#{cli.name} #{Enum.join(command_path, " ")} [COMMAND] --help' for more information on a command.")
      end
    else
      IO.puts("Command not found")
    end
  end

  ## Helper Functions

  # Retrieves the command based on the command path
  defp get_command(%CLI{} = cli, []) do
    %Command{
      name: cli.name,
      description: cli.description,
      subcommands: cli.spec,
      flags: [],
      args: []
    }
  end

  defp get_command(%CLI{} = cli, [root | rest]) do
    if root_cmd = Enum.find(cli.spec, &(&1.name == root)) do
      get_subcommand(root_cmd, rest)
    end
  end

  defp get_subcommand(cmd, []) do
    cmd
  end

  defp get_subcommand(cmd, [name | rest]) do
    if subcmd = Enum.find(cmd.subcommands || [], &(&1.name == name)) do
      get_subcommand(subcmd, rest)
    end
  end

  # Builds the usage line for the help output
  defp build_usage_line(cli_name, command_path, cmd) do
    parts = [cli_name | Enum.map(command_path, &Atom.to_string/1)]

    # Include options
    parts = if cmd.flags == [], do: parts, else: parts ++ ["[OPTIONS]"]

    # Include subcommands
    parts =
      if cmd.subcommands == [] do
        parts
      else
        parts ++ ["[COMMAND]"]
      end

    # Include arguments
    arg_strings =
      Enum.map(cmd.args || [], fn arg ->
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
        IO.puts("  #{subcmd.name}  #{subcmd.description || "No description"}")
      end)

      IO.puts("")
    end
  end

  # Displays arguments if any
  defp display_arguments(cmd) do
    if cmd.args != [] do
      IO.puts("Arguments:")

      Enum.each(cmd.args, &display_arg/1)

      IO.puts("")
    end
  end

  defp display_arg(arg) do
    arg_name = if arg.required, do: "<#{arg.name}>", else: "[#{arg.name}]"
    IO.puts("  #{arg_name}  Type: #{format_arg_type(arg.type)}")
  end

  # Displays options (flags), including the help option
  defp display_options(cmd) do
    all_flags = cmd.flags || []

    if all_flags != [] do
      IO.puts("Options:")

      Enum.each(all_flags, &display_option/1)
    end
  end

  defp display_option(flag) do
    short = if flag.short, do: "-#{flag.short}, ", else: "    "
    type = if flag.type == :boolean, do: "", else: " <#{String.upcase(to_string(flag.type))}>"
    IO.puts("  #{short}--#{flag.name}#{type}  #{flag.description || "No description"}")
  end

  # Formats the argument type for display
  defp format_arg_type({:list, type}), do: "List of #{inspect(type)}"
  defp format_arg_type({:enum, values}), do: "One of #{inspect(values)}"
  defp format_arg_type(type), do: "#{inspect(type)}"
end
