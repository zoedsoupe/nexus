defmodule Nexus.ParserTest do
  use ExUnit.Case
  alias Nexus.Parser

  @ast MyCLI.__nexus_cli_commands__()

  test "parses copy command with verbose flag and arguments" do
    input = "file copy --verbose file1.txt file2.txt"

    expected = %{
      command: "copy",
      flags: %{verbose: true},
      args: %{source: "file1.txt", dest: "file2.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@ast, input)
    assert parsed == expected
  end

  test "parses move command with force flag and arguments" do
    input = "file move --force source.txt dest.txt"

    expected = %{
      command: "move",
      flags: %{force: true},
      args: %{source: "source.txt", dest: "dest.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@ast, input)
    assert parsed == expected
  end

  test "parses delete command with multiple flags and arguments" do
    input = "file delete --force --recursive file1.txt file2.txt"

    expected = %{
      command: "delete",
      flags: %{force: true, recursive: true},
      args: %{targets: ["file1.txt", "file2.txt"]}
    }

    assert {:ok, parsed} = Parser.parse_ast(@ast, input)
    assert parsed == expected
  end

  test "fails on unknown subcommand" do
    input = "file unknown_command"
    assert {:error, ["Unknown subcommand: unknown_command"]} = Parser.parse_ast(@ast, input)
  end

  test "fails on missing required arguments" do
    input = "file copy --verbose file1.txt"
    assert {:error, ["Invalid input."]} = Parser.parse_ast(@ast, input)
  end

  test "parses copy command with short flag and arguments" do
    input = "file copy -v file1.txt file2.txt"

    expected = %{
      command: "copy",
      flags: %{verbose: true},
      args: %{source: "file1.txt", dest: "file2.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@ast, input)
    assert parsed == expected
  end

  test "parses move command with verbose flag using short alias" do
    input = "file move -v source.txt dest.txt"

    expected = %{
      command: "move",
      flags: %{verbose: true},
      args: %{source: "source.txt", dest: "dest.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@ast, input)
    assert parsed == expected
  end

  test "parses delete command with flags in different order" do
    input = "file delete --recursive --force file1.txt file2.txt"

    expected = %{
      command: "delete",
      flags: %{recursive: true, force: true},
      args: %{targets: ["file1.txt", "file2.txt"]}
    }

    assert {:ok, parsed} = Parser.parse_ast(@ast, input)
    assert parsed == expected
  end

  test "parses copy command with flag value" do
    input = "file copy --level=3 file1.txt file2.txt"

    expected = %{
      command: "copy",
      flags: %{level: 3},
      args: %{source: "file1.txt", dest: "file2.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@ast, input)
    assert parsed == expected
  end

  test "parses copy command with negative flag value" do
    input = "file copy --level=-2 file1.txt file2.txt"

    expected = %{
      command: "copy",
      flags: %{level: -2},
      args: %{source: "file1.txt", dest: "file2.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@ast, input)
    assert parsed == expected
  end

  test "parses copy command with float flag value" do
    input = "file copy --level=2.5 file1.txt file2.txt"

    expected = %{
      command: "copy",
      flags: %{level: 2.5},
      args: %{source: "file1.txt", dest: "file2.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@ast, input)
    assert parsed == expected
  end

  test "parses copy command with quoted string argument" do
    input = "file copy --verbose \"file 1.txt\" \"file 2.txt\""

    expected = %{
      command: "copy",
      flags: %{verbose: true},
      args: %{source: "file 1.txt", dest: "file 2.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@ast, input)
    assert parsed == expected
  end
end
