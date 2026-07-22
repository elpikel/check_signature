defmodule CheckSignature.Verification.Workers.SupremeCourtHarvest do
  @moduledoc """
  Harvests Supreme Court (SN) Rulings into the `rulings` index.

  Two ways to run:
    * default (hourly cron) — page newest-first, stop at the first fully-known page.
    * `%{"backfill" => true}` — page all the way back (ignore the stop), to pull in
      the historical corpus. Kick one off once; it chains to completion.
  """

  use Oban.Worker, queue: :harvest_supreme_court, max_attempts: 5

  alias CheckSignature.Rulings
  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification.Sources.SupremeCourt

  @pages_per_run 20
  @delay_ms 1_500

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
    {entries, next} = SupremeCourt.harvest_page(cursor)

    normalized = Enum.map(entries, &Signature.normalize(to_string(&1[:signature])))
    known = Rulings.existing_for_source("supreme_court", normalized)
    Rulings.upsert_all("supreme_court", entries)
    fresh = Enum.count(normalized, &(not MapSet.member?(known, &1)))

    cond do
      next == :done ->
        :ok

      not backfill and fresh == 0 and entries != [] ->
        :ok

      true ->
        Process.sleep(@delay_ms + :rand.uniform(@delay_ms))
        harvest(next, backfill, budget - 1)
    end
  end
end
