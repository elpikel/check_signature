defmodule CheckSignature.Verification.Workers.CommonCourtsHarvestTest do
  use CheckSignature.DataCase, async: true

  alias CheckSignature.Rulings
  alias CheckSignature.Rulings.Ruling
  alias CheckSignature.Signatures.Signature
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

  defp count(source) do
    Repo.aggregate(from(r in Ruling, where: r.source == ^source), :count)
  end
end
