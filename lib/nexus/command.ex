defmodule Nexus.Command do
  @moduledoc false

  import Ecto.Changeset, only: [cast: 3, apply_action: 2]

  @options_schema %{
    name: :atom,
    type: :string,
    required: :boolean
  }

  @allowed_options Map.keys(@options_schema)

  @spec parse(keyword) :: {:ok, map} | {:error, Ecto.Changeset.t()}
  def parse(raw_opts) do
    params = Map.new(raw_opts)

    {%{}, @options_schema}
    |> cast(params, @allowed_options)
    |> apply_action(:parse)
  end
end
