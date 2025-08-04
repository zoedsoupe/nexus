defmodule Nexus.CLI.HelpTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Nexus.CLI
  alias Nexus.CLI.Argument
  alias Nexus.CLI.Command
  alias Nexus.CLI.Flag
  alias Nexus.CLI.Help

  defmodule TestHandler do
    @moduledoc false
    @behaviour CLI

    def description, do: "Test CLI handler"
    def version, do: "1.0.0"

    def handle_input(_, _), do: :ok
  end

  @simple_cli %CLI{
    name: :test_cli,
    handler: TestHandler,
    description: "A simple test CLI",
    spec: []
  }

  @complex_cli %CLI{
    name: :complex_cli,
    handler: TestHandler,
    description: "A complex test CLI with subcommands",
    spec: [
      %Command{
        name: :file,
        description: "File operations",
        flags: [
          %Flag{name: :verbose, short: :v, type: :boolean, description: "Enable verbose output"},
          %Flag{name: :force, short: :f, type: :boolean, description: "Force operation"}
        ],
        args: [],
        subcommands: [
          %Command{
            name: :copy,
            description: "Copy files",
            flags: [
              %Flag{name: :recursive, short: :r, type: :boolean, description: "Copy recursively"},
              %Flag{name: :level, type: :integer, description: "Compression level", default: nil}
            ],
            args: [
              %Argument{name: :source, type: :string, required: true},
              %Argument{name: :dest, type: :string, required: true}
            ],
            subcommands: []
          }
        ]
      },
      %Command{
        name: :version,
        description: "Show version",
        flags: [],
        args: [],
        subcommands: []
      }
    ]
  }

  describe "display/2 with simple CLI" do
    test "displays root help for empty command path" do
      output =
        capture_io(fn ->
          Help.display(@simple_cli, [])
        end)

      assert output =~ "Usage: test_cli"
      assert output =~ "A simple test CLI"
    end

    test "displays root help with no command path argument" do
      output =
        capture_io(fn ->
          Help.display(@simple_cli)
        end)

      assert output =~ "Usage: test_cli"
      assert output =~ "A simple test CLI"
    end
  end

  describe "display/2 with complex CLI" do
    test "displays root help with available commands" do
      output =
        capture_io(fn ->
          Help.display(@complex_cli, [])
        end)

      assert output =~ "Usage: complex_cli [COMMAND]"
      assert output =~ "A complex test CLI with subcommands"
      assert output =~ "Commands:"
      assert output =~ "file  File operations"
      assert output =~ "version  Show version"
      assert output =~ "Use 'complex_cli  [COMMAND] --help' for more information"
    end

    test "displays help for specific command" do
      output =
        capture_io(fn ->
          Help.display(@complex_cli, [:file])
        end)

      assert output =~ "Usage: complex_cli file [OPTIONS] [COMMAND]"
      assert output =~ "File operations"
      assert output =~ "Commands:"
      assert output =~ "copy  Copy files"
      assert output =~ "Options:"
      assert output =~ "-v, --verbose  Enable verbose output"
      assert output =~ "-f, --force  Force operation"
    end

    test "displays help for nested subcommand" do
      output =
        capture_io(fn ->
          Help.display(@complex_cli, [:file, :copy])
        end)

      assert output =~ "Usage: complex_cli file copy [OPTIONS] <source> <dest>"
      assert output =~ "Copy files"
      assert output =~ "Arguments:"
      assert output =~ "<source>  Type: :string"
      assert output =~ "<dest>  Type: :string"
      assert output =~ "Options:"
      assert output =~ "-r, --recursive  Copy recursively"
      assert output =~ "--level <INTEGER>  Compression level"
    end

    test "displays help for command without subcommands" do
      output =
        capture_io(fn ->
          Help.display(@complex_cli, [:version])
        end)

      assert output =~ "Usage: complex_cli version"
      assert output =~ "Show version"
      refute output =~ "Commands:"
      refute output =~ "Use 'complex_cli version [COMMAND] --help'"
    end

    test "displays 'Command not found' for non-existent command" do
      output =
        capture_io(fn ->
          Help.display(@complex_cli, [:nonexistent])
        end)

      assert output =~ "Command not found"
    end

    test "displays 'Command not found' for non-existent nested command" do
      output =
        capture_io(fn ->
          Help.display(@complex_cli, [:file, :nonexistent])
        end)

      assert output =~ "Command not found"
    end
  end

  describe "banner integration" do
    defmodule BannerHandler do
      @moduledoc false
      @behaviour CLI

      def description, do: "CLI with banner"
      def version, do: "1.0.0"
      def banner, do: "My Custom Banner"

      def handle_input(_, _), do: :ok
    end

    test "displays banner when handler implements banner/0" do
      cli_with_banner = %CLI{
        name: :banner_cli,
        handler: BannerHandler,
        description: "CLI with custom banner",
        spec: []
      }

      output =
        capture_io(fn ->
          Help.display(cli_with_banner, [])
        end)

      assert output =~ "My Custom Banner"
      assert output =~ "Usage: banner_cli"
    end
  end

  describe "usage line formatting" do
    test "includes OPTIONS when flags are present" do
      output =
        capture_io(fn ->
          Help.display(@complex_cli, [:file])
        end)

      assert output =~ "Usage: complex_cli file [OPTIONS] [COMMAND]"
    end

    test "includes COMMAND when subcommands are present" do
      output =
        capture_io(fn ->
          Help.display(@complex_cli, [])
        end)

      assert output =~ "Usage: complex_cli [COMMAND]"
    end

    test "includes arguments in usage line" do
      output =
        capture_io(fn ->
          Help.display(@complex_cli, [:file, :copy])
        end)

      assert output =~ "Usage: complex_cli file copy [OPTIONS] <source> <dest>"
    end
  end

  describe "argument display" do
    test "shows required arguments with angle brackets" do
      output =
        capture_io(fn ->
          Help.display(@complex_cli, [:file, :copy])
        end)

      assert output =~ "<source>  Type: :string"
      assert output =~ "<dest>  Type: :string"
    end

    test "would show optional arguments with square brackets" do
      # This test shows how optional arguments would be displayed
      # The current CLI spec doesn't have optional args, but this tests the format
      optional_cli = %CLI{
        name: :optional_cli,
        handler: TestHandler,
        description: "CLI with optional args",
        spec: [
          %Command{
            name: :test,
            description: "Test command",
            flags: [],
            args: [
              %Argument{name: :optional_arg, type: :string, required: false}
            ],
            subcommands: []
          }
        ]
      }

      output =
        capture_io(fn ->
          Help.display(optional_cli, [:test])
        end)

      assert output =~ "Usage: optional_cli test [optional_arg]"
      assert output =~ "[optional_arg]  Type: :string"
    end
  end

  describe "flag display formatting" do
    test "shows flags with short versions" do
      output =
        capture_io(fn ->
          Help.display(@complex_cli, [:file])
        end)

      assert output =~ "-v, --verbose  Enable verbose output"
      assert output =~ "-f, --force  Force operation"
    end

    test "shows flags without short versions" do
      output =
        capture_io(fn ->
          Help.display(@complex_cli, [:file, :copy])
        end)

      assert output =~ "    --level <INTEGER>  Compression level"
    end

    test "shows boolean flags without type indicator" do
      output =
        capture_io(fn ->
          Help.display(@complex_cli, [:file])
        end)

      assert output =~ "-v, --verbose  Enable verbose output"
      refute output =~ "--verbose <BOOLEAN>"
    end

    test "shows non-boolean flags with type indicator" do
      output =
        capture_io(fn ->
          Help.display(@complex_cli, [:file, :copy])
        end)

      assert output =~ "--level <INTEGER>  Compression level"
    end
  end

  describe "edge cases" do
    @empty_spec_cli %CLI{
      name: :empty_cli,
      handler: TestHandler,
      description: nil,
      spec: []
    }

    test "handles CLI with no description" do
      output =
        capture_io(fn ->
          Help.display(@empty_spec_cli, [])
        end)

      assert output =~ "Usage: empty_cli"
      refute output =~ "nil"
    end

    test "handles commands with no description" do
      no_desc_cli = %CLI{
        name: :no_desc_cli,
        handler: TestHandler,
        description: "CLI",
        spec: [
          %Command{
            name: :cmd,
            description: nil,
            flags: [],
            args: [],
            subcommands: []
          }
        ]
      }

      output =
        capture_io(fn ->
          Help.display(no_desc_cli, [])
        end)

      assert output =~ "cmd  No description"
    end

    test "handles flags with no description" do
      no_flag_desc_cli = %CLI{
        name: :no_flag_desc_cli,
        handler: TestHandler,
        description: "CLI",
        spec: [
          %Command{
            name: :cmd,
            description: "Command",
            flags: [
              %Flag{name: :no_desc, type: :boolean, description: nil}
            ],
            args: [],
            subcommands: []
          }
        ]
      }

      output =
        capture_io(fn ->
          Help.display(no_flag_desc_cli, [:cmd])
        end)

      assert output =~ "--no_desc  No description"
    end
  end
end
