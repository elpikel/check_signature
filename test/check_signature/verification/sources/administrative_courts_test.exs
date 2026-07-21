defmodule CheckSignature.Verification.Sources.AdministrativeCourtsTest do
  use ExUnit.Case, async: true

  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification.Ruling
  alias CheckSignature.Verification.Sources.AdministrativeCourts, as: CBOSA

  @hit File.read!("test/support/fixtures/cbosa_hit.html")
  @miss File.read!("test/support/fixtures/cbosa_miss.html")
  @find File.read!("test/support/fixtures/cbosa_find_page.html")

  defp sig(s), do: Signature.new(s)

  describe "parse_listing/1 (harvest enumeration) against a real /cbo/find page" do
    test "extracts every result as a harvest entry with signature and url" do
      entries = CBOSA.parse_listing(@find)

      # The fixture page holds 10 results.
      assert length(entries) == 10

      first = hd(entries)
      assert first.signature == "II SA/Łd 580/25"
      assert first.url =~ "https://orzeczenia.nsa.gov.pl/doc/"
    end

    test "an empty/exhausted page yields no entries (harvest stop signal)" do
      assert CBOSA.parse_listing("<html><body>nothing</body></html>") == []
    end
  end

  describe "parse/2 against real CBOSA fixtures" do
    test "matches the exact queried signature and links its ruling" do
      assert {:matched, %Ruling{} = ruling} = CBOSA.parse(@hit, sig("II FSK 1442/21"))
      assert ruling.url == "https://orzeczenia.nsa.gov.pl/doc/E35DDF933C"
      assert Signature.same?(sig("II FSK 1442/21"), ruling.signature)
    end

    test "also matches a related ruling that CBOSA returned in the same list" do
      assert {:matched, %Ruling{url: url}} = CBOSA.parse(@hit, sig("I SA/Wr 115/21"))
      assert url == "https://orzeczenia.nsa.gov.pl/doc/2C91042447"
    end

    test "results present but none is ours → confirmed_absent, not a false match" do
      assert :confirmed_absent = CBOSA.parse(@hit, sig("II FSK 1442/99"))
    end

    test "CBOSA 'no results' banner → confirmed_absent" do
      assert :confirmed_absent = CBOSA.parse(@miss, sig("IX FSK 8888/23"))
    end

    test "an unrecognised page → errored, never a false absence" do
      assert {:errored, :unrecognized_results} =
               CBOSA.parse("<html><body>maintenance</body></html>", sig("II FSK 1/20"))
    end
  end
end
