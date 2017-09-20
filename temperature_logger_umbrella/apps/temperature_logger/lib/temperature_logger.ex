defmodule TemperatureLogger do
  use Application

  @moduledoc """
  Documentation for TemperatureLogger.
  """

  def start(_type, _args) do
    TemperatureLogger.Supervisor.start_link(name: TemperatureLogger.Supervisor)
  end
end
