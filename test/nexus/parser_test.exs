defmodule Nexus.ParserTest do
  use ExUnit.Case

  alias Nexus.Parser

  @cli MyCLI.__nexus_spec__()
  @program @cli.name

  test "parses other single root command" do
    input = "version"

    expected = %{
      program: @program,
      command: [:version],
      flags: %{help: false},
      args: %{}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "parses any other root command" do
    input = "folder merge -rc folder1 folder2 folder3"

    expected = %{
      program: @program,
      command: [:folder, :merge],
      flags: %{help: false, recursive: true, level: nil},
      args: %{targets: ~w(folder1 folder2 folder3)}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "parses copy command with verbose flag and arguments" do
    input = "file copy --verbose file1.txt file2.txt"

    expected = %{
      program: @program,
      command: [:file, :copy],
      flags: %{verbose: true, level: nil, recursive: false, help: false},
      args: %{source: "file1.txt", dest: "file2.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "parses move command with force flag and arguments" do
    input = "file move --force source.txt dest.txt"

    expected = %{
      program: @program,
      command: [:file, :move],
      flags: %{force: true, verbose: false, help: false},
      args: %{source: "source.txt", dest: "dest.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "parses delete command with multiple flags and arguments" do
    input = "file delete --force --recursive file1.txt file2.txt"

    expected = %{
      program: @program,
      command: [:file, :delete],
      flags: %{force: true, recursive: true, verbose: false, help: false},
      args: %{targets: ["file1.txt", "file2.txt"]}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "fails on missing required arguments" do
    input = "file copy --verbose file1.txt"
    assert {:error, ["Missing required argument 'dest'"]} = Parser.parse_ast(@cli, input)
  end

  test "parses copy command with short flag and arguments" do
    input = "file copy -v file1.txt file2.txt"

    expected = %{
      program: @program,
      command: [:file, :copy],
      flags: %{verbose: true, level: nil, recursive: false, help: false},
      args: %{source: "file1.txt", dest: "file2.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "parses move command with verbose flag using short alias" do
    input = "file move -v source.txt dest.txt"

    expected = %{
      program: @program,
      command: [:file, :move],
      flags: %{verbose: true, force: false, help: false},
      args: %{source: "source.txt", dest: "dest.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "parses delete command with flags in different order" do
    input = "file delete --recursive --force file1.txt file2.txt"

    expected = %{
      program: @program,
      command: [:file, :delete],
      flags: %{recursive: true, force: true, verbose: false, help: false},
      args: %{targets: ["file1.txt", "file2.txt"]}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "parses copy command with flag value" do
    input = "file copy --level=3 file1.txt file2.txt"

    expected = %{
      program: @program,
      command: [:file, :copy],
      flags: %{level: 3, recursive: false, verbose: false, help: false},
      args: %{source: "file1.txt", dest: "file2.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "parses copy command with negative flag value" do
    input = "file copy --level=-2 file1.txt file2.txt"

    expected = %{
      program: @program,
      command: [:file, :copy],
      flags: %{level: -2, verbose: false, recursive: false, help: false},
      args: %{source: "file1.txt", dest: "file2.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "parses copy command with quoted string argument" do
    input = ~s(file copy --verbose "file 1.txt" "file 2.txt")

    expected = %{
      program: @program,
      command: [:file, :copy],
      flags: %{verbose: true, level: nil, recursive: false, help: false},
      args: %{source: "file 1.txt", dest: "file 2.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "parses command with --help flag" do
    input = "file copy --help"

    expected = %{
      program: @program,
      command: [:file, :copy],
      flags: %{help: true},
      args: %{}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "parses command with -h flag" do
    input = "file copy -h"

    expected = %{
      program: @program,
      command: [:file, :copy],
      flags: %{help: true},
      args: %{}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "parses command with arguments and then --help flag (should stop parsing at --help)" do
    input = "file copy source.txt dest.txt --help"

    expected = %{
      program: @program,
      command: [:file, :copy],
      flags: %{help: true},
      args: %{}
    }

    assert {:ok, ^expected} = Parser.parse_ast(@cli, input)
  end

  test "parses command with --help flag among other flags (should stop parsing at --help)" do
    input = "file copy --verbose --help"

    expected = %{
      program: @program,
      command: [:file, :copy],
      flags: %{help: true},
      args: %{}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "parses command with -h flag and other flags and arguments" do
    input = "file copy -v -h source.txt dest.txt"

    expected = %{
      program: @program,
      command: [:file, :copy],
      flags: %{help: true},
      args: %{}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end
end
