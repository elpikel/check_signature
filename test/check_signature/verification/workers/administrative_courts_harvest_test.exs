defmodule CheckSignature.Verification.Workers.AdministrativeCourtsHarvestTest do
  use CheckSignature.DataCase, async: true

  alias CheckSignature.Rulings.Ruling
  alias CheckSignature.Verification.Workers.AdministrativeCourtsHarvest

  @listing File.read!("test/support/fixtures/cbosa_find_page.html")

  test "harvests CBOSA rulings into the index" do
    Req.Test.stub(CheckSignature.HarvestStub, fn conn -> Req.Test.text(conn, @listing) end)

    assert :ok = AdministrativeCourtsHarvest.perform(%Oban.Job{args: %{}})

    assert count("administrative_courts") == 10
  end

  defp count(source) do
    Repo.aggregate(from(r in Ruling, where: r.source == ^source), :count)
  end
end
