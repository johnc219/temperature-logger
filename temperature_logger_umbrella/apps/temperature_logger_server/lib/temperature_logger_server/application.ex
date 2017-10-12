defmodule TemperatureLoggerServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: TemperatureLoggerServer.TaskSupervisor},
      Supervisor.child_spec(
        {Task, fn -> TemperatureLoggerServer.accept(4040) end},
        restart: :permanent
      )
    ]

    opts = [strategy: :one_for_one, name: TemperatureLoggerServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
