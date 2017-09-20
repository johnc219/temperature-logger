defmodule TemperatureLogger.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      {TemperatureLogger.Writer, name: TemperatureLogger.Writer},
      {TemperatureLogger.Listener, name: TemperatureLogger.Listener}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
