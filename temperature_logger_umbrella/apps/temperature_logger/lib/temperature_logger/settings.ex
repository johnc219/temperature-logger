defmodule TemperatureLogger.Settings do
  @default_log_path Path.join([".", "log", "temperature_logger.log"])

  # 10 seconds
  @default_period 10

  # 1 seconds
  @min_period 1

  def default_log_path do
    @default_log_path
  end

  def default_period do
    @default_period
  end

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
