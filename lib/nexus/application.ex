defmodule Nexus.Application do
  @moduledoc false

  use Application

  def start(_, _) do
    config_env = Application.get_env(:nexus, :config_env)
    children = fetch_children_by_config_env(config_env)
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end

  defp fetch_children_by_config_env(:test), do: []

  defp fetch_children_by_config_env(_) do
    [{Nexus.RuntimeStorage, :nexus_storage}]
  end
end
