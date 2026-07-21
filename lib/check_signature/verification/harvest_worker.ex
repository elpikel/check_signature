defmodule CheckSignature.Verification.HarvestWorker do
  @moduledoc """
  Harvests a Source's Rulings into the local `rulings` index (harvest, don't
  live-scrape-per-request).

  Incremental sync: page the Source **newest-first** via `Source.harvest_page/1`
  and stop at the first **fully-known page** — one whose Signatures are all already
  stored for this Source. That page is the seam where this run meets the previous
  one; requiring the *whole* page to be known tolerates a back-dated Ruling
  interleaved within the boundary page.

  Each run harvests at most `@pages_per_run` pages, then, if it hasn't caught up
  yet, re-enqueues itself carrying the next `cursor` in its args — so the first-run
  backfill (empty index ⇒ every page is fresh, all the way to `:done`) is chunked
  across jobs rather than one job running forever.
  """

  use Oban.Worker, queue: :harvest_http, max_attempts: 5

  require Logger

  alias CheckSignature.Rulings
  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification.Sources

  # How many pages a single job harvests before handing off to a follow-up job.
  @pages_per_run 20

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"source" => key} = args}) do
    with {:ok, module} <- Sources.fetch(key) do
      harvest(key, module, args["cursor"], @pages_per_run)
    else
      :error -> {:cancel, "unknown source: #{inspect(key)}"}
    end
  end

  # Page budget for this run is exhausted but we haven't caught up: persist
  # progress by enqueuing a follow-up job that resumes from `cursor`.
  defp harvest(key, _module, cursor, 0), do: continue(key, cursor)

  defp harvest(key, module, cursor, budget) do
    {entries, next} = module.harvest_page(cursor)
    fresh_count = upsert_page(key, entries)

    Logger.debug("harvest #{key}: page +#{fresh_count}/#{length(entries)}")

    cond do
      next == :done ->
        :ok

      fresh_count == 0 and entries != [] ->
        # Fully-known page — we've caught up to the previous run.
        :ok

      true ->
        harvest(key, module, next, budget - 1)
    end
  end

  # Upsert the whole page (idempotent) and report how many Signatures were new,
  # using one bulk existence check rather than a query per row.
  defp upsert_page(_key, []), do: 0

  defp upsert_page(key, entries) do
    normalized = Enum.map(entries, &Signature.normalize(to_string(&1[:signature])))
    known = Rulings.existing_for_source(key, normalized)
    fresh_count = Enum.count(normalized, &(not MapSet.member?(known, &1)))

    Rulings.upsert_all(key, entries)
    fresh_count
  end

  defp continue(key, cursor) do
    %{"source" => key, "cursor" => cursor}
    |> new()
    |> Oban.insert()

    :ok
  end
end
