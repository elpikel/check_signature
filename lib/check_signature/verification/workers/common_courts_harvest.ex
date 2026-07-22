defmodule CheckSignature.Verification.Workers.CommonCourtsHarvest do
  @moduledoc """
  Harvests common-court (sądy powszechne, via SAOS) Rulings into the `rulings` index.

  Two ways to run:
    * default (hourly cron) — page newest-first, stop at the first fully-known page.
    * `%{"backfill" => true}` — page all the way to the end (ignore the stop), to
      pull in the historical corpus. Kick one off once; it chains to completion.
  """

  use Oban.Worker, queue: :harvest_common_courts, max_attempts: 5

  alias CheckSignature.Rulings
  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification.Sources.CommonCourts

  @pages_per_run 20

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    harvest(args["cursor"], args["backfill"] == true, @pages_per_run)
  end

  # Budget spent — resume in a follow-up job on this same queue.
  defp harvest(cursor, backfill, 0) do
    Oban.insert(new(%{"cursor" => cursor, "backfill" => backfill}))
    :ok
  end

  defp harvest(cursor, backfill, budget) do
    {entries, next} = CommonCourts.harvest_page(cursor)

    normalized = Enum.map(entries, &Signature.normalize(to_string(&1[:signature])))
    known = Rulings.existing_for_source("common_courts", normalized)
    Rulings.upsert_all("common_courts", entries)
    fresh = Enum.count(normalized, &(not MapSet.member?(known, &1)))

    # No delay between pages — SAOS is slow enough (~7s/page) to pace itself.
    cond do
      next == :done -> :ok
      not backfill and fresh == 0 and entries != [] -> :ok
      true -> harvest(next, backfill, budget - 1)
    end
  end
end
