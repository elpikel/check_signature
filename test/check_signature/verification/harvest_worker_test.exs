defmodule CheckSignature.Verification.HarvestWorkerTest do
  use CheckSignature.DataCase, async: false

  alias CheckSignature.Rulings
  alias CheckSignature.Verification.HarvestWorker
  alias CheckSignature.Verification.Sources.FakeHarvestSource

  setup do
    # Register the scripted fake under key "fake" for the duration of the test.
    Application.put_env(:check_signature, :extra_harvest_sources, %{"fake" => FakeHarvestSource})
    on_exit(fn -> Application.delete_env(:check_signature, :extra_harvest_sources) end)
    :ok
  end

  defp perform do
    HarvestWorker.perform(%Oban.Job{args: %{"source" => "fake"}})
  end

  test "first run backfills the whole listing (empty index ⇒ every page fresh)" do
    assert :ok = perform()

    # FakeHarvestSource scripts 3 pages × 2 rulings.
    sigs = "fake" |> stored_signatures()
    assert length(sigs) == 6
    assert "II CSK 1/20" in sigs
    assert "II CSK 6/20" in sigs
  end

  test "harvest is idempotent — re-running adds no duplicates" do
    assert :ok = perform()
    assert :ok = perform()
    assert length(stored_signatures("fake")) == 6
  end

  test "incremental stops at the first fully-known page" do
    # Pre-seed exactly page 1's signatures, so the very first page is fully-known.
    Rulings.upsert_all("fake", [
      %{signature: "II CSK 1/20", url: "https://fake.test/1"},
      %{signature: "II CSK 2/20", url: "https://fake.test/2"}
    ])

    assert :ok = perform()

    # It saw page 1, found nothing new, and stopped — pages 2 and 3 were never
    # fetched, so their signatures are absent.
    sigs = stored_signatures("fake")
    assert "II CSK 1/20" in sigs
    refute "II CSK 3/20" in sigs
    assert length(sigs) == 2
  end

  test "unknown source cancels the job rather than crash-looping" do
    assert {:cancel, _} = HarvestWorker.perform(%Oban.Job{args: %{"source" => "nope"}})
  end

  defp stored_signatures(source) do
    import Ecto.Query

    Repo.all(
      from r in CheckSignature.Rulings.Ruling,
        where: r.source == ^source,
        select: r.signature_normalized
    )
  end
end
