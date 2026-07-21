defmodule CheckSignature.RulingsTest do
  use CheckSignature.DataCase, async: true

  alias CheckSignature.Rulings
  alias CheckSignature.Signatures.Signature

  defp entry(sig, id) do
    %{signature: sig, url: "https://ex.test/#{id}"}
  end

  describe "upsert_all/2" do
    test "inserts rows, normalizing the signature" do
      assert {2, nil} =
               Rulings.upsert_all("supreme_court", [
                 entry("II CSK 1/20", 1),
                 entry("I ACa 5/19", 2)
               ])

      assert [row] = Rulings.lookup(Signature.normalize("ii csk 1/20"))
      assert row.signature_normalized == "II CSK 1/20"
      assert row.source == "supreme_court"
    end

    test "is idempotent on {source, signature} — re-harvest updates, never duplicates" do
      Rulings.upsert_all("supreme_court", [entry("II CSK 1/20", 1)])

      Rulings.upsert_all("supreme_court", [
        %{signature: "II CSK 1/20", url: "https://ex.test/new"}
      ])

      assert [row] = Rulings.lookup("II CSK 1/20")
      assert row.url == "https://ex.test/new"
    end

    test "same signature under a different source is a distinct row" do
      Rulings.upsert_all("supreme_court", [entry("II CSK 1/20", 1)])
      Rulings.upsert_all("administrative_courts", [entry("II CSK 1/20", 9)])

      assert length(Rulings.lookup("II CSK 1/20")) == 2
    end

    test "empty list is a no-op" do
      assert {0, nil} = Rulings.upsert_all("supreme_court", [])
    end
  end

  describe "lookup_many/1" do
    test "returns rows for any of the given normalized signatures" do
      Rulings.upsert_all("supreme_court", [entry("II CSK 1/20", 1), entry("II CSK 2/20", 2)])

      found = Rulings.lookup_many(["II CSK 1/20", "II CSK 2/20", "NOPE 9/99"])

      assert Enum.map(found, & &1.signature_normalized) |> Enum.sort() == [
               "II CSK 1/20",
               "II CSK 2/20"
             ]
    end

    test "empty input short-circuits" do
      assert Rulings.lookup_many([]) == []
    end
  end

  describe "existing_for_source/2 (harvest stop condition)" do
    test "returns only the already-stored signatures for that source" do
      Rulings.upsert_all("supreme_court", [entry("II CSK 1/20", 1)])

      existing = Rulings.existing_for_source("supreme_court", ["II CSK 1/20", "II CSK 2/20"])
      assert MapSet.member?(existing, "II CSK 1/20")
      refute MapSet.member?(existing, "II CSK 2/20")
    end

    test "is scoped to the source" do
      Rulings.upsert_all("administrative_courts", [entry("II CSK 1/20", 1)])
      assert Rulings.existing_for_source("supreme_court", ["II CSK 1/20"]) == MapSet.new()
    end
  end
end
