defmodule CheckSignature.VerificationTest do
  use CheckSignature.DataCase, async: true

  alias CheckSignature.Rulings
  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification
  alias CheckSignature.Verification.Ruling

  describe "check/1 — answered solely from the harvested index" do
    test "a Signature in the index is :found, linking the harvested Ruling" do
      Rulings.upsert_all("supreme_court", [
        %{signature: "II CSK 1/20", url: "https://sn.test/1", court: "SN"}
      ])

      assert %{status: :found, matches: [%{source: "Sąd Najwyższy", ruling: %Ruling{url: url}}]} =
               Verification.check(Signature.new("II CSK 1/20"))

      assert url == "https://sn.test/1"
    end

    test "a Signature absent from the index is :inconclusive, never :not_found" do
      assert %{status: :inconclusive, matches: [], checked: []} =
               Verification.check(Signature.new("II CSK 999/20"))
    end

    test "a match is reported under each Source that harvested it" do
      Rulings.upsert_all("supreme_court", [%{signature: "II CSK 1/20", url: "https://sn.test/1"}])

      Rulings.upsert_all("administrative_courts", [
        %{signature: "II CSK 1/20", url: "https://cbosa.test/1"}
      ])

      assert %{status: :found, matches: matches} =
               Verification.check(Signature.new("II CSK 1/20"))

      assert Enum.map(matches, & &1.source) |> Enum.sort() == [
               "Sąd Najwyższy",
               "Sądy administracyjne"
             ]
    end
  end

  describe "check_document/1" do
    test "returns one Verdict per unique Signature in document order" do
      Rulings.upsert_all("supreme_court", [%{signature: "II CSK 1/20", url: "https://sn.test/1"}])

      doc = "Zob. II CSK 1/20 oraz rzekomy wyrok II CSK 999/20."

      assert [%{status: :found}, %{status: :inconclusive}] = Verification.check_document(doc)
    end

    test "an empty document yields no verdicts" do
      assert Verification.check_document("Brak sygnatur w tym piśmie.") == []
    end
  end
end
