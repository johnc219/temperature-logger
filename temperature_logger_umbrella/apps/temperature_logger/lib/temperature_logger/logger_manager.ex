defmodule TemperatureLogger.LoggerManager do
  @moduledoc """
  Utility for adding and removing Logger backends for a particular log file
  path.
  """

  @spec add_backend(String.t()) :: term()
  def add_backend(path) do
    Logger.add_backend({LoggerFileBackend, path})

    Logger.configure_backend(
      {LoggerFileBackend, path},
      path: path,
      level: :info,
      format: "\n$time, $message\n",
      metadata_filter: [application: :temperature_logger]
    )
  end

  @spec remove_backend(String.t()) :: term()
  def remove_backend(path) do
    Logger.remove_backend({LoggerFileBackend, path})
  end
end
