defmodule TemperatureLogger.Application do
  use Application

  @moduledoc """
  Application entry point.
  """

  def start(_type, _args) do
    TemperatureLogger.Supervisor.start_link(name: TemperatureLogger.Supervisor)
  end
end
