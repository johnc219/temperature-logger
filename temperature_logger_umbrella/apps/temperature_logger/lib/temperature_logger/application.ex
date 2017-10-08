defmodule TemperatureLogger.Application do
  use Application

  @moduledoc """
  Documentation for TemperatureLogger.Application
  """

  def start(_type, _args) do
    TemperatureLogger.Supervisor.start_link(name: TemperatureLogger.Supervisor)
  end
end
