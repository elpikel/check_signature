defmodule CheckSignature.Verification.Sources.Retry do
  @moduledoc """
  Retry a Source lookup once (by default) on a transient failure.

  Scraped portals — sn.pl behind Incapsula especially — intermittently block a
  request under load, which a lookup reports as `{:errored, _}`. A single retry
  after a short backoff recovers those momentary blocks so a real Ruling isn't
  degraded to *inconclusive*. `:matched` and `:confirmed_absent` are final and
  returned immediately; only `{:errored, _}` is retried.
  """

  alias CheckSignature.Verification.Verdict

  @spec with_retry((-> Verdict.source_outcome()), non_neg_integer(), non_neg_integer()) ::
          Verdict.source_outcome()
  def with_retry(fun, retries \\ 1, backoff_ms \\ 500) when is_function(fun, 0) do
    case fun.() do
      {:errored, _} when retries > 0 ->
        Process.sleep(backoff_ms)
        with_retry(fun, retries - 1, backoff_ms)

      result ->
        result
    end
  end
end
