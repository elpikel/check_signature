defmodule CheckSignature.RateLimiter do
  @moduledoc """
  A small in-memory, fixed-window rate limiter backed by ETS.

  Used to stop a single client hammering the scraped portals through the public
  form (one of the guardrails from the design). Deliberately lightweight: no
  persistence, approximate under heavy contention — good enough for a small tool,
  and it fails open if the table is somehow unavailable.
  """

  use GenServer

  @table __MODULE__

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Records a hit for `key` and reports whether it is within the limit of `max`
  hits per `window_ms`. Returns `:ok` or `{:error, :rate_limited}`.
  """
  @spec hit(term(), pos_integer(), pos_integer()) :: :ok | {:error, :rate_limited}
  def hit(key, max, window_ms) do
    now = System.system_time(:millisecond)

    case :ets.lookup(@table, key) do
      [{^key, _count, window_end}] when window_end > now ->
        if :ets.update_counter(@table, key, {2, 1}) > max do
          {:error, :rate_limited}
        else
          :ok
        end

      _expired_or_missing ->
        :ets.insert(@table, {key, 1, now + window_ms})
        :ok
    end
  rescue
    ArgumentError -> :ok
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      write_concurrency: true,
      read_concurrency: true
    ])

    {:ok, %{}}
  end
end
