defmodule CheckSignature.Verification.VerdictTest do
  use ExUnit.Case, async: true

  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification.{Ruling, Verdict}

  defp sig, do: Signature.new("II CSK 234/19")
  defp ruling, do: %Ruling{signature: "II CSK 234/19", url: "https://example.test/1"}

  describe "derive/2" do
    test "any match wins → :found, even if another source errored" do
      verdict =
        Verdict.derive(sig(), [
          {"Common", :confirmed_absent},
          {"SN", {:matched, ruling()}},
          {"NSA", {:errored, :timeout}}
        ])

      assert verdict.status == :found
      assert [%{source: "SN"}] = verdict.matches
      assert verdict.errored == ["NSA"]
    end

    test "all sources confirm absence → :not_found" do
      verdict =
        Verdict.derive(sig(), [
          {"Common", :confirmed_absent},
          {"SN", :confirmed_absent}
        ])

      assert verdict.status == :not_found
      assert verdict.matches == []
      assert verdict.checked == ["Common", "SN"]
    end

    test "no match but a source errored → :inconclusive, never an accusation" do
      verdict =
        Verdict.derive(sig(), [
          {"Common", :confirmed_absent},
          {"SN", {:errored, :timeout}}
        ])

      assert verdict.status == :inconclusive
      assert verdict.errored == ["SN"]
    end
  end
end
