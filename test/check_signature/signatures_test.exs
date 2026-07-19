defmodule CheckSignature.SignaturesTest do
  use ExUnit.Case, async: true

  alias CheckSignature.Signatures

  defp normalized(document) do
    document |> Signatures.extract() |> Map.fetch!(:signatures) |> Enum.map(& &1.normalized)
  end

  describe "extract/2" do
    test "finds a plain Supreme Court signature" do
      assert normalized("Zgodnie z wyrokiem II CSK 234/19 sąd orzekł...") == ["II CSK 234/19"]
    end

    test "finds the different court families in one document" do
      doc = """
      Powołano orzeczenia: II CSK 234/19 (SN), I Ns 45/2019 (rejonowy),
      III SA/Wa 1234/19 (WSA) oraz II FSK 1234/19 (NSA).
      """

      assert normalized(doc) == [
               "II CSK 234/19",
               "I NS 45/2019",
               "III SA/WA 1234/19",
               "II FSK 1234/19"
             ]
    end

    test "collapses duplicates regardless of spacing and case" do
      doc = "Por. II CSK 234/19, a także II  CSK  234 / 19 oraz ii csk 234/19."
      assert normalized(doc) == ["II CSK 234/19"]
    end

    test "keeps the raw form for display while normalizing for matching" do
      [sig] = "See III  SA / Wa 1234/19." |> Signatures.extract() |> Map.fetch!(:signatures)
      assert sig.raw == "III  SA / Wa 1234/19"
      assert sig.normalized == "III SA/WA 1234/19"
    end

    test "reports truncation when over the cap" do
      doc = Enum.map_join(1..5, " ", fn n -> "II CSK #{n}/19" end)
      result = Signatures.extract(doc, max: 3)

      assert length(result.signatures) == 3
      assert result.unique_count == 5
      assert result.truncated? == true
    end

    test "returns nothing for text without signatures" do
      result = Signatures.extract("This paragraph cites no rulings at all.")
      assert result.signatures == []
      assert result.truncated? == false
    end
  end
end
