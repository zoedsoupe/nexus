defmodule Nexus.Parser.DSLTest do
  use ExUnit.Case

  import Nexus.Parser.DSL

  doctest Nexus.Parser.DSL

  describe "literal/1" do
    test "matches exact string" do
      parser = literal("hello")
      assert parse(parser, ["hello", "world"]) == {:ok, "hello", ["world"]}
    end

    test "fails on different string" do
      parser = literal("hello")
      assert parse(parser, ["goodbye", "world"]) == {:error, "Expected 'hello', got 'goodbye'"}
    end

    test "fails on empty input" do
      parser = literal("hello")
      assert parse(parser, []) == {:error, "Expected 'hello', got end of input"}
    end
  end

  describe "choice/1" do
    test "returns first successful match" do
      parser = choice([literal("git"), literal("svn"), literal("hg")])
      assert parse(parser, ["git", "status"]) == {:ok, "git", ["status"]}
      assert parse(parser, ["svn", "status"]) == {:ok, "svn", ["status"]}
      assert parse(parser, ["hg", "status"]) == {:ok, "hg", ["status"]}
    end

    test "fails when no choice matches" do
      parser = choice([literal("add"), literal("commit")])
      assert {:error, message} = parse(parser, ["push", "origin"])
      assert String.contains?(message, "No choice matched")
    end

    test "works with empty list" do
      parser = choice([])
      assert {:error, message} = parse(parser, ["anything"])
      assert String.contains?(message, "No choice matched")
    end
  end

  describe "many/1" do
    test "matches zero occurrences" do
      parser = many(literal("very"))
      assert parse(parser, ["good", "day"]) == {:ok, [], ["good", "day"]}
    end

    test "matches multiple occurrences" do
      parser = many(literal("very"))
      assert parse(parser, ["very", "very", "good"]) == {:ok, ["very", "very"], ["good"]}
    end

    test "stops at first non-match" do
      parser = many(literal("la"))
      assert parse(parser, ["la", "la", "di", "da"]) == {:ok, ["la", "la"], ["di", "da"]}
    end
  end

  describe "many1/1" do
    test "requires at least one match" do
      parser = many1(literal("file"))
      assert parse(parser, ["file", "file", "done"]) == {:ok, ["file", "file"], ["done"]}
    end

    test "fails with zero matches" do
      parser = many1(literal("file"))
      assert parse(parser, ["done"]) == {:error, "Expected at least one match"}
    end
  end

  describe "sequence/1" do
    test "applies parsers in order" do
      parser = sequence([literal("git"), literal("commit")])
      assert parse(parser, ["git", "commit", "--all"]) == {:ok, ["git", "commit"], ["--all"]}
    end

    test "fails if any parser fails" do
      parser = sequence([literal("git"), literal("commit")])
      assert parse(parser, ["git", "push", "--all"]) == {:error, "Expected 'commit', got 'push'"}
    end

    test "works with empty sequence" do
      parser = sequence([])
      assert parse(parser, ["anything"]) == {:ok, [], ["anything"]}
    end
  end

  describe "optional/1" do
    test "returns result when parser succeeds" do
      parser = optional(literal("--verbose"))
      assert parse(parser, ["--verbose", "file.txt"]) == {:ok, "--verbose", ["file.txt"]}
    end

    test "returns nil when parser fails" do
      parser = optional(literal("--verbose"))
      assert parse(parser, ["file.txt"]) == {:ok, nil, ["file.txt"]}
    end
  end

  describe "flag_parser/0" do
    test "parses long flag without value" do
      parser = flag_parser()
      assert parse(parser, ["--verbose"]) == {:ok, {:flag, :long, "verbose", true}, []}
    end

    test "parses long flag with value" do
      parser = flag_parser()
      assert parse(parser, ["--output=file.txt"]) == {:ok, {:flag, :long, "output", "file.txt"}, []}
    end

    test "parses short flag without value" do
      parser = flag_parser()
      assert parse(parser, ["-v"]) == {:ok, {:flag, :short, "v", true}, []}
    end

    test "parses short flag with value" do
      parser = flag_parser()
      assert parse(parser, ["-o=file.txt"]) == {:ok, {:flag, :short, "o", "file.txt"}, []}
    end

    test "fails on non-flag input" do
      parser = flag_parser()
      assert {:error, _} = parse(parser, ["file.txt"])
    end
  end

  describe "long_flag_parser/0" do
    test "parses long flag" do
      parser = long_flag_parser()
      assert parse(parser, ["--help", "command"]) == {:ok, {:flag, :long, "help", true}, ["command"]}
    end

    test "parses long flag with equals value" do
      parser = long_flag_parser()
      assert parse(parser, ["--level=5", "command"]) == {:ok, {:flag, :long, "level", "5"}, ["command"]}
    end

    test "fails on short flag" do
      parser = long_flag_parser()
      assert {:error, message} = parse(parser, ["-h"])
      assert String.contains?(message, "Expected long flag")
    end

    test "fails on regular argument" do
      parser = long_flag_parser()
      assert {:error, message} = parse(parser, ["file.txt"])
      assert String.contains?(message, "Expected long flag")
    end
  end

  describe "short_flag_parser/0" do
    test "parses short flag" do
      parser = short_flag_parser()
      assert parse(parser, ["-h", "command"]) == {:ok, {:flag, :short, "h", true}, ["command"]}
    end

    test "parses short flag with equals value" do
      parser = short_flag_parser()
      assert parse(parser, ["-l=5", "command"]) == {:ok, {:flag, :short, "l", "5"}, ["command"]}
    end

    test "fails on long flag" do
      parser = short_flag_parser()
      assert {:error, message} = parse(parser, ["--help"])
      assert String.contains?(message, "Expected short flag")
    end

    test "fails on regular argument" do
      parser = short_flag_parser()
      assert {:error, message} = parse(parser, ["file.txt"])
      assert String.contains?(message, "Expected short flag")
    end
  end

  describe "command_parser/1" do
    test "matches valid command" do
      parser = command_parser(["commit", "push", "pull"])
      assert parse(parser, ["commit", "--message"]) == {:ok, "commit", ["--message"]}
    end

    test "fails on invalid command" do
      parser = command_parser(["add", "remove"])
      assert {:error, message} = parse(parser, ["commit", "--message"])
      assert String.contains?(message, "Expected one of [add, remove]")
      assert String.contains?(message, "got 'commit'")
    end

    test "fails on empty input" do
      parser = command_parser(["add", "remove"])
      assert parse(parser, []) == {:error, "Expected command, got end of input"}
    end
  end

  describe "value_parser/1" do
    test "parses string values" do
      parser = value_parser(:string)
      assert parse(parser, ["hello", "world"]) == {:ok, "hello", ["world"]}
    end

    test "parses integer values" do
      parser = value_parser(:integer)
      assert parse(parser, ["42", "rest"]) == {:ok, 42, ["rest"]}
    end

    test "parses negative integer values" do
      parser = value_parser(:integer)
      assert parse(parser, ["-42", "rest"]) == {:ok, -42, ["rest"]}
    end

    test "fails on invalid integer" do
      parser = value_parser(:integer)
      assert {:error, message} = parse(parser, ["abc", "rest"])
      assert String.contains?(message, "Invalid integer value")
    end

    test "parses float values" do
      parser = value_parser(:float)
      assert parse(parser, ["3.14", "rest"]) == {:ok, 3.14, ["rest"]}
    end

    test "parses negative float values" do
      parser = value_parser(:float)
      assert parse(parser, ["-3.14", "rest"]) == {:ok, -3.14, ["rest"]}
    end

    test "fails on invalid float" do
      parser = value_parser(:float)
      assert {:error, message} = parse(parser, ["abc", "rest"])
      assert String.contains?(message, "Invalid float value")
    end

    test "parses boolean true" do
      parser = value_parser(:boolean)
      assert parse(parser, ["true", "rest"]) == {:ok, true, ["rest"]}
    end

    test "parses boolean false" do
      parser = value_parser(:boolean)
      assert parse(parser, ["false", "rest"]) == {:ok, false, ["rest"]}
    end

    test "fails on invalid boolean" do
      parser = value_parser(:boolean)
      assert {:error, message} = parse(parser, ["maybe", "rest"])
      assert String.contains?(message, "Invalid boolean value")
      assert String.contains?(message, "Expected 'true' or 'false'")
    end

    test "fails on empty input" do
      parser = value_parser(:string)
      assert parse(parser, []) == {:error, "Expected string value, got end of input"}
    end
  end

  describe "quoted_string_parser/0" do
    test "removes quotes from quoted string" do
      parser = quoted_string_parser()
      assert parse(parser, ["\"hello world\"", "rest"]) == {:ok, "hello world", ["rest"]}
    end

    test "handles unquoted string" do
      parser = quoted_string_parser()
      assert parse(parser, ["hello", "world"]) == {:ok, "hello", ["world"]}
    end

    test "handles empty quoted string" do
      parser = quoted_string_parser()
      assert parse(parser, ["\"\"", "rest"]) == {:ok, "", ["rest"]}
    end

    test "fails on empty input" do
      parser = quoted_string_parser()
      assert parse(parser, []) == {:error, "Expected string, got end of input"}
    end
  end

  describe "rest_parser/0" do
    test "consumes all remaining input" do
      parser = rest_parser()
      assert parse(parser, ["file1", "file2", "file3"]) == {:ok, ["file1", "file2", "file3"], []}
    end

    test "works with empty input" do
      parser = rest_parser()
      assert parse(parser, []) == {:ok, [], []}
    end
  end

  describe "parse_typed_value/2" do
    test "parses string values" do
      assert parse_typed_value("hello", :string) == {:ok, "hello"}
    end

    test "parses integer values" do
      assert parse_typed_value("42", :integer) == {:ok, 42}
      assert parse_typed_value("-42", :integer) == {:ok, -42}
      assert parse_typed_value("0", :integer) == {:ok, 0}
    end

    test "fails on invalid integer" do
      assert {:error, message} = parse_typed_value("abc", :integer)
      assert String.contains?(message, "Invalid integer value")
    end

    test "parses float values" do
      assert parse_typed_value("3.14", :float) == {:ok, 3.14}
      assert parse_typed_value("-3.14", :float) == {:ok, -3.14}
      assert parse_typed_value("0.0", :float) == {:ok, 0.0}
    end

    test "fails on invalid float" do
      assert {:error, message} = parse_typed_value("abc", :float)
      assert String.contains?(message, "Invalid float value")
    end

    test "parses boolean values" do
      assert parse_typed_value("true", :boolean) == {:ok, true}
      assert parse_typed_value("false", :boolean) == {:ok, false}
    end

    test "fails on invalid boolean" do
      assert {:error, message} = parse_typed_value("maybe", :boolean)
      assert String.contains?(message, "Invalid boolean value")
    end
  end

  describe "unquote_string/1" do
    test "removes surrounding quotes" do
      assert unquote_string("\"hello world\"") == "hello world"
    end

    test "handles string without quotes" do
      assert unquote_string("hello") == "hello"
    end

    test "handles empty quoted string" do
      assert unquote_string("\"\"") == ""
    end

    test "handles string with internal quotes" do
      assert unquote_string(~s("say \\"hello\\"")) == "say \\\"hello\\\""
    end
  end

  describe "map/2" do
    test "transforms parser result" do
      parser = "hello" |> literal() |> map(&String.upcase/1)
      assert parse(parser, ["hello", "world"]) == {:ok, "HELLO", ["world"]}
    end

    test "preserves error" do
      parser = "hello" |> literal() |> map(&String.upcase/1)
      assert {:error, _} = parse(parser, ["goodbye", "world"])
    end
  end

  describe "tag/2" do
    test "tags successful result" do
      parser = "commit" |> literal() |> tag(:command)
      assert parse(parser, ["commit", "message"]) == {:ok, {:command, "commit"}, ["message"]}
    end

    test "preserves error" do
      parser = "commit" |> literal() |> tag(:command)
      assert {:error, _} = parse(parser, ["push", "message"])
    end
  end

  describe "ignore/1" do
    test "ignores parser result" do
      parser = ignore(literal("--"))
      assert parse(parser, ["--", "args"]) == {:ok, nil, ["args"]}
    end

    test "preserves error" do
      parser = ignore(literal("--"))
      assert {:error, _} = parse(parser, ["args"])
    end
  end

  describe "separated_by/2" do
    test "parses single element" do
      parser = separated_by(literal("file"), literal(","))
      assert parse(parser, ["file"]) == {:ok, ["file"], []}
    end

    test "parses multiple elements" do
      parser = separated_by(literal("file"), literal(","))
      assert parse(parser, ["file", ",", "file", ",", "file"]) == {:ok, ["file", "file", "file"], []}
    end

    test "handles trailing elements" do
      parser = separated_by(literal("file"), literal(","))
      assert parse(parser, ["file", ",", "file", "done"]) == {:ok, ["file", "file"], ["done"]}
    end

    test "fails if first element doesn't match" do
      parser = separated_by(literal("file"), literal(","))
      assert {:error, _} = parse(parser, ["dir", ",", "file"])
    end
  end

  describe "complex parser combinations" do
    test "parses git commit command with flags" do
      parser =
        sequence([
          literal("git"),
          command_parser(["commit", "push", "pull"]),
          many(flag_parser())
        ])

      input = ["git", "commit", "--message", "--verbose"]

      expected_flags = [
        {:flag, :long, "message", true},
        {:flag, :long, "verbose", true}
      ]

      assert parse(parser, input) == {:ok, ["git", "commit", expected_flags], []}
    end

    test "parses file operations with arguments" do
      parser =
        sequence([
          literal("file"),
          command_parser(["copy", "move", "delete"]),
          many(quoted_string_parser())
        ])

      input = ["file", "copy", "\"source file.txt\"", "\"dest file.txt\""]
      expected_args = ["source file.txt", "dest file.txt"]

      assert parse(parser, input) == {:ok, ["file", "copy", expected_args], []}
    end

    test "parses optional flags with required arguments" do
      parser =
        sequence([
          literal("deploy"),
          optional(flag_parser()),
          many1(quoted_string_parser())
        ])

      # With flag
      input1 = ["deploy", "--force", "app.jar"]
      assert parse(parser, input1) == {:ok, ["deploy", {:flag, :long, "force", true}, ["app.jar"]], []}

      # Without flag
      input2 = ["deploy", "app.jar", "config.yml"]
      assert parse(parser, input2) == {:ok, ["deploy", nil, ["app.jar", "config.yml"]], []}
    end

    test "handles choice between different command structures" do
      git_parser = sequence([literal("git"), command_parser(["commit", "push"])])
      npm_parser = sequence([literal("npm"), command_parser(["install", "test"])])

      parser = choice([git_parser, npm_parser])

      assert parse(parser, ["git", "commit"]) == {:ok, ["git", "commit"], []}
      assert parse(parser, ["npm", "install"]) == {:ok, ["npm", "install"], []}
      assert {:error, _} = parse(parser, ["make", "build"])
    end
  end
end
