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

  test "handles empty input gracefully" do
    input = ""

    assert {:error, reasons} = Parser.parse_ast(@cli, input)
    assert is_list(reasons)
    assert length(reasons) > 0
  end

  test "handles only whitespace input" do
    input = "   \t\n   "

    assert {:error, reasons} = Parser.parse_ast(@cli, input)
    assert is_list(reasons)
  end

  test "handles malformed quoted strings" do
    input = ~s(file copy "unclosed quote file1.txt file2.txt)

    assert {:error, reasons} = Parser.parse_ast(@cli, input)
    assert is_list(reasons)
    assert Enum.any?(reasons, &String.contains?(&1, "Unclosed quoted string"))
  end

  test "handles unknown flags gracefully" do
    input = "file copy --unknown file1.txt file2.txt"

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    refute parsed.flags[:unknown]
  end

  test "handles integer parsing errors gracefully" do
    input = "file copy --level=abc file1.txt file2.txt"

    assert_raise ArgumentError, fn ->
      Parser.parse_ast(@cli, input)
    end
  end

  test "validates command existence" do
    input = "nonexistent command"

    assert {:error, reasons} = Parser.parse_ast(@cli, input)
    assert is_list(reasons)

    flattened_reasons = List.flatten(reasons)
    assert Enum.any?(flattened_reasons, &String.contains?(&1, "not found"))
  end

  test "handles flags after arguments" do
    input = "file copy file1.txt file2.txt --verbose"

    expected = %{
      program: @program,
      command: [:file, :copy],
      flags: %{verbose: true, level: nil, recursive: false, help: false},
      args: %{source: "file1.txt", dest: "file2.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "handles special characters in file names" do
    input = ~s(file copy "file@#$%.txt" "dest file!.txt")

    expected = %{
      program: @program,
      command: [:file, :copy],
      flags: %{verbose: false, level: nil, recursive: false, help: false},
      args: %{source: "file@#$%.txt", dest: "dest file!.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "parses list arguments without flags" do
    input = "folder merge folder1 folder2 folder3"

    expected = %{
      program: @program,
      command: [:folder, :merge],
      flags: %{help: false, recursive: false, level: nil},
      args: %{targets: ["folder1", "folder2", "folder3"]}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "handles duplicate flags - last one wins" do
    input = "file copy --level=1 --level=2 file1.txt file2.txt"

    expected = %{
      program: @program,
      command: [:file, :copy],
      flags: %{level: 2, verbose: false, recursive: false, help: false},
      args: %{source: "file1.txt", dest: "file2.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "parses negative numbers correctly in flag values" do
    input = "folder merge --level=-5 folder1"

    expected = %{
      program: @program,
      command: [:folder, :merge],
      flags: %{level: -5, recursive: false, help: false},
      args: %{targets: ["folder1"]}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "handles mixed quoted and unquoted arguments" do
    input = ~s(file copy "quoted file.txt" unquoted.txt)

    expected = %{
      program: @program,
      command: [:file, :copy],
      flags: %{verbose: false, level: nil, recursive: false, help: false},
      args: %{source: "quoted file.txt", dest: "unquoted.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "handles non-integer values for integer flags - should raise error" do
    input = ~s(folder merge --level="5=test" folder1)

    assert_raise ArgumentError, fn ->
      Parser.parse_ast(@cli, input)
    end
  end

  test "handles empty quoted strings" do
    input = ~s(file copy "" "")

    expected = %{
      program: @program,
      command: [:file, :copy],
      flags: %{verbose: false, level: nil, recursive: false, help: false},
      args: %{source: "", dest: ""}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "handles unicode characters in arguments" do
    input = ~s(file copy "файл.txt" "目的地.txt")

    expected = %{
      program: @program,
      command: [:file, :copy],
      flags: %{verbose: false, level: nil, recursive: false, help: false},
      args: %{source: "файл.txt", dest: "目的地.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "handles boolean flag values explicitly" do
    input = "file copy --verbose=true file1.txt file2.txt"

    expected = %{
      program: @program,
      command: [:file, :copy],
      flags: %{verbose: true, level: nil, recursive: false, help: false},
      args: %{source: "file1.txt", dest: "file2.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "handles false boolean flag values" do
    input = "file copy --verbose=false file1.txt file2.txt"

    expected = %{
      program: @program,
      command: [:file, :copy],
      flags: %{verbose: false, level: nil, recursive: false, help: false},
      args: %{source: "file1.txt", dest: "file2.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end

  test "handles subcommands with exact matching - should fail for unknown subcommand" do
    input = "file cop file1.txt file2.txt"

    assert {:error, reasons} = Parser.parse_ast(@cli, input)
    assert is_list(reasons)
  end

  test "handles extremely long input gracefully" do
    long_filename = String.duplicate("a", 1000)
    input = "file copy #{long_filename} dest.txt"

    expected = %{
      program: @program,
      command: [:file, :copy],
      flags: %{verbose: false, level: nil, recursive: false, help: false},
      args: %{source: long_filename, dest: "dest.txt"}
    }

    assert {:ok, parsed} = Parser.parse_ast(@cli, input)
    assert parsed == expected
  end
end
