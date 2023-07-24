ExUnit.start()

defmodule MyCLITest do
  use Nexus

  defcommand :test, type: :string

  @impl true
  def version, do: "0.0.0"

  @impl true
  def handle_input(:test, args) do
    args
  end

  Nexus.parse()
end
