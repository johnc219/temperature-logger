defmodule TemperatureLoggerServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: TemperatureLoggerServer.Worker.start_link(arg)
      # {TemperatureLoggerServer.Worker, arg},
      {Task.Supervisor, name: TemperatureLoggerServer.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> TemperatureLoggerServer.accept(4040) end}, restart: :permanent)
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TemperatureLoggerServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
