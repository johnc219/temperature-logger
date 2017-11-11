defmodule TemperatureLogger.Settings do
  @moduledoc """
  Utility for generating an appropriate settings map for a particular port.
  """

  alias Nerves.UART

  # Texas Instruments
  @vendor_id 1105

  # MSP430G2 Rev.1.4
  @product_id 62514

  @default_log_path Path.join([".", "log", "temperature_logger.log"])

  # 10 seconds
  @default_period 10

  # 1 seconds
  @min_period 1

  @spec default_port() :: String.t | nil
  def default_port do
    ports = UART.enumerate()

    results =
      Enum.find(ports, fn {_k, v} ->
        vendor_id = Map.get(v, :vendor_id)
        product_id = Map.get(v, :product_id)

        vendor_id == @vendor_id and product_id == @product_id
      end)

    case results do
      {path, _details} -> path
      nil -> nil
    end
  end

  @spec default_log_path() :: String.t()
  def default_log_path do
    @default_log_path
  end

  @spec default_period() :: pos_integer()
  def default_period do
    @default_period
  end

  @spec generate(String.t(), pos_integer()) :: map()
  def generate(log_path, period) do
    case calculate_upper_limit(period) do
      {:ok, upper_limit} ->
        settings = %{
          log_path: log_path,
          period: period,
          lower_limit: 0,
          upper_limit: upper_limit,
          count: 0,
          direction: -1
        }

        {:ok, settings}

      {:error, error} ->
        {:error, error}
    end
  end

  @spec next(map()) :: {:crest | :trough | :regular, map()}
  def next(settings) do
    %{
      count: count,
      upper_limit: upper_limit,
      lower_limit: lower_limit
    } = settings

    case count do
      ^upper_limit ->
        {:crest, next(settings, :inflection_point)}

      ^lower_limit ->
        {:trough, next(settings, :inflection_point)}

      _ ->
        {:regular, next(settings, :regular)}
    end
  end

  defp next(settings, :inflection_point) do
    %{direction: direction, count: count} = settings
    new_direction = -1 * direction
    new_count = count + new_direction

    %{settings | direction: new_direction, count: new_count}
  end

  defp next(settings, :regular) do
    %{direction: direction, count: count} = settings
    new_count = count + direction

    %{settings | count: new_count}
  end

  defp calculate_upper_limit(period) when period < @min_period do
    {:error, :period_less_than_min_period}
  end

  defp calculate_upper_limit(period) when rem(period, @min_period) != 0 do
    {:error, :period_not_multiple_of_min_period}
  end

  defp calculate_upper_limit(period) do
    upper_limit = div(period, @min_period)
    {:ok, upper_limit}
  end
end
