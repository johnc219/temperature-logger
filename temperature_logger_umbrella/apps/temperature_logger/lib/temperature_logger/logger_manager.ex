defmodule TemperatureLogger.LoggerManager do
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

  def remove_backend(path) do
    Logger.remove_backend({LoggerFileBackend, path})
  end
end
