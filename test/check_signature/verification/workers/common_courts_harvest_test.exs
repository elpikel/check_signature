defmodule CheckSignature.Verification.Workers.CommonCourtsHarvestTest do
  use CheckSignature.DataCase, async: true
  use Oban.Testing, repo: CheckSignature.Repo

  alias CheckSignature.Rulings
  alias CheckSignature.Rulings.Ruling
  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification.Sources.CommonCourts
  alias CheckSignature.Verification.Workers.CommonCourtsHarvest

  @dump "test/support/fixtures/saos_common_dump.json" |> File.read!() |> Jason.decode!()

  test "harvests SAOS common-court rulings into the index" do
    # Every page returns the same fixture, so the second page is fully-known and
    # the worker stops — upserting the 20 judgments exactly once.
    Req.Test.stub(CheckSignature.HarvestStub, fn conn -> Req.Test.json(conn, @dump) end)

    assert :ok = CommonCourtsHarvest.perform(%Oban.Job{args: %{}})

    assert [%Ruling{source: "common_courts", url: "https://www.saos.org.pl/judgments/31345"}] =
             Rulings.lookup(Signature.normalize("I ACa 772/13"))

    assert count("common_courts") == 20
  end

  test "backfill mode pages past already-known pages instead of stopping" do
    # Pre-seed every signature so the page is fully-known: incremental would stop
    # at once. Backfill must NOT — it keeps paging (here to the budget), then
    # enqueues a continuation to resume.
    Rulings.upsert_all("common_courts", CommonCourts.parse_dump(@dump))
    Req.Test.stub(CheckSignature.HarvestStub, fn conn -> Req.Test.json(conn, @dump) end)

    assert :ok = CommonCourtsHarvest.perform(%Oban.Job{args: %{"backfill" => true}})

    assert_enqueued(worker: CommonCourtsHarvest, args: %{"backfill" => true})
  end

  test "incremental mode stops at a fully-known page (no continuation)" do
    Rulings.upsert_all("common_courts", CommonCourts.parse_dump(@dump))
    Req.Test.stub(CheckSignature.HarvestStub, fn conn -> Req.Test.json(conn, @dump) end)

    assert :ok = CommonCourtsHarvest.perform(%Oban.Job{args: %{}})

    refute_enqueued(worker: CommonCourtsHarvest)
  end

  test "a failed request raises so Oban retries — the backfill chain never silently ends" do
    Req.Test.stub(CheckSignature.HarvestStub, fn conn ->
      Plug.Conn.send_resp(conn, 500, "boom")
    end)

    assert_raise RuntimeError, ~r/harvest failed/, fn ->
      CommonCourtsHarvest.perform(%Oban.Job{args: %{}})
    end
  end

  defp count(source) do
    Repo.aggregate(from(r in Ruling, where: r.source == ^source), :count)
  end
end
