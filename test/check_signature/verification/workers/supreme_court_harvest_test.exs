defmodule CheckSignature.Verification.Workers.SupremeCourtHarvestTest do
  use CheckSignature.DataCase, async: true

  alias CheckSignature.Rulings.Ruling
  alias CheckSignature.Verification.Workers.SupremeCourtHarvest

  @listing File.read!("test/support/fixtures/sn_day_listing.html")

  test "harvests SN rulings into the index" do
    Req.Test.stub(CheckSignature.HarvestStub, fn conn -> Req.Test.text(conn, @listing) end)

    assert :ok = SupremeCourtHarvest.perform(%Oban.Job{args: %{}})

    assert count("supreme_court") == 80
  end

  defp count(source) do
    Repo.aggregate(from(r in Ruling, where: r.source == ^source), :count)
  end
end
