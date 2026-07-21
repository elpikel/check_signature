defmodule CheckSignature.Verification.Sources.SupremeCourtTest do
  use ExUnit.Case, async: true

  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification.Ruling
  alias CheckSignature.Verification.Sources.SupremeCourt, as: SN

  @hit File.read!("test/support/fixtures/sn_hit.html")
  @miss File.read!("test/support/fixtures/sn_miss.html")
  @listing File.read!("test/support/fixtures/sn_day_listing.html")

  defp sig(s), do: Signature.new(s)

  describe "parse_listing/1 (harvest enumeration) against a real day listing" do
    test "extracts one entry per ruling, deduped by ItemSID" do
      entries = SN.parse_listing(@listing)

      # 80 rulings, each linked twice (signature + 'szczegóły') → 80 deduped entries.
      assert length(entries) == 80
      assert Enum.all?(entries, &(&1.url =~ "ItemSID="))

      # Every kept entry is signature-shaped — no 'szczegóły' noise leaks through.
      assert Enum.any?(entries, &(&1.signature == "I CNP 19/19"))
      refute Enum.any?(entries, &(&1.signature =~ ~r/szczeg/))
    end

    test "a page with no ruling links yields no entries (harvest stop signal)" do
      assert SN.parse_listing("<html><body>brak</body></html>") == []
    end
  end

  describe "parse/2 against real sn.pl fixtures" do
    test "matches the exact queried signature and links its ruling" do
      assert {:matched, %Ruling{} = ruling} = SN.parse(@hit, sig("III CZP 25/19"))
      assert Signature.same?(sig("III CZP 25/19"), ruling.signature)
      assert ruling.url =~ "sn.pl"
      assert ruling.url =~ "ItemSID="
    end

    test "results present but none is ours → confirmed_absent" do
      assert :confirmed_absent = SN.parse(@hit, sig("III CZP 99/99"))
    end

    test "SN 'no results' banner → confirmed_absent" do
      assert :confirmed_absent = SN.parse(@miss, sig("II CSK 9999/47"))
    end

    test "an unrecognised page → errored, never a false absence" do
      assert {:errored, :unrecognized_results} =
               SN.parse("<html><body>przerwa techniczna</body></html>", sig("II CSK 1/20"))
    end
  end
end
