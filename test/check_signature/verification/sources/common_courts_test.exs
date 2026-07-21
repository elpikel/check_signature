defmodule CheckSignature.Verification.Sources.CommonCourtsTest do
  use ExUnit.Case, async: true

  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification.Sources.CommonCourts

  @dump "test/support/fixtures/saos_common_dump.json" |> File.read!() |> Jason.decode!()

  describe "lookup/1 (harvest-only Source, never scraped live)" do
    test "returns :harvest_only rather than manufacturing a false absence" do
      assert {:errored, :harvest_only} = CommonCourts.lookup(Signature.new("I ACa 566/12"))
    end
  end

  describe "parse_dump/1 (harvest enumeration) against a real SAOS response" do
    test "extracts one entry per case number, with signature and url" do
      entries = CommonCourts.parse_dump(@dump)

      # The fixture holds 20 COMMON judgments.
      assert length(entries) == 20

      first = hd(entries)
      assert first.signature == "I ACa 772/13"
      assert first.url == "https://www.saos.org.pl/judgments/31345"
    end

    test "a response with no items yields no entries (harvest stop signal)" do
      assert CommonCourts.parse_dump(%{"items" => []}) == []
      assert CommonCourts.parse_dump(%{}) == []
    end
  end
end
