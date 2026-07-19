defmodule CheckSignature.Verification.Sources.CommonCourtsTest do
  use ExUnit.Case, async: true

  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification.Ruling
  alias CheckSignature.Verification.Sources.CommonCourts

  @hit "test/support/fixtures/saos_common_hit.json" |> File.read!() |> Jason.decode!()
  @miss "test/support/fixtures/saos_common_miss.json" |> File.read!() |> Jason.decode!()

  defp sig(s), do: Signature.new(s)

  describe "parse/2 against real SAOS fixtures" do
    test "matches the exact queried case number and links the SAOS judgment" do
      assert {:matched, %Ruling{} = ruling} = CommonCourts.parse(@hit, sig("I ACa 566/12"))
      assert Signature.same?(sig("I ACa 566/12"), ruling.signature)
      assert ruling.url == "https://www.saos.org.pl/judgments/4"
    end

    test "items present but none is ours → confirmed_absent" do
      assert :confirmed_absent = CommonCourts.parse(@hit, sig("I ACa 999/99"))
    end

    test "empty SAOS result → confirmed_absent" do
      assert :confirmed_absent = CommonCourts.parse(@miss, sig("I ACa 99999/15"))
    end

    test "a response without an items list → errored, never a false absence" do
      assert {:errored, :unrecognized_response} =
               CommonCourts.parse(%{"error" => "boom"}, sig("I ACa 1/20"))
    end
  end
end
