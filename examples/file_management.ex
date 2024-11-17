defmodule MyCLI do
  @moduledoc """
  MyCLI provides file operations such as copy, move, and delete using the Nexus.CLI DSL.
  """

  use Nexus.CLI

  defcommand :file do
    description "Performs file operations such as copy, move, and delete."

    subcommand :copy do
      description "Copies files from source to destination."

      value :string, required: true, as: :source
      value :string, required: true, as: :dest

      flag :verbose do
        short :v
        description "Enables verbose output."
      end

      flag :recursive do
        short :rc
        description "Copies directories recursively."
      end
    end

    subcommand :move do
      description "Moves files from source to destination."

      value :string, required: true, as: :source
      value :string, required: true, as: :dest

      flag :force do
        short :f
        description "Forces the move without confirmation."
      end

      flag :verbose do
        short :v
        description "Enables verbose output."
      end
    end

    subcommand :delete do
      description "Deletes specified files or directories."

      value {:list, :string}, required: true, as: :targets

      flag :force do
        short :f
        description "Forces deletion without confirmation."
      end

      flag :recursive do
        short :rc
        description "Deletes directories recursively."
      end

      flag :verbose do
        short :v
        description "Enables verbose output."
      end
    end
  end

  # @impl Nexus.CLI
  @spec handle_input([atom], map) :: :ok | {:error, any}
  def handle_input([:file, :copy], %{args: args, flags: flags}) do
    if flags.verbose do
      IO.puts("Copying from #{args.source} to #{args.dest}")
    end

    if flags.recursive do
      IO.puts("Recursive copy enabled")
    end

    # Implement actual copy logic here
    IO.puts("Copied #{args.source} to #{args.dest}")
    :ok
  end

  def handle_input([:file, :move], %{args: args, flags: flags}) do
    if flags.verbose do
      IO.puts("Moving from #{args.source} to #{args.dest}")
    end

    if flags.force do
      IO.puts("Force move enabled")
    end

    # Implement actual move logic here
    IO.puts("Moved #{args.source} to #{args.dest}")
    :ok
  end

  def handle_input([:file, :delete], %{args: args, flags: flags}) do
    if flags.verbose do
      IO.puts("Deleting targets: #{Enum.join(args.targets, ", ")}")
    end

    if flags.recursive do
      IO.puts("Recursive delete enabled")
    end

    if flags.force do
      IO.puts("Force delete enabled")
    end

    # Implement actual delete logic here
    Enum.each(args.targets, fn target ->
      IO.puts("Deleted #{target}")
    end)

    :ok
  end

  def handle_input(_command, _params) do
    IO.puts("Unknown command or invalid parameters")
    :error
  end
end
