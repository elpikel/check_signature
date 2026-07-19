defmodule CheckSignature.VerificationTest do
  use CheckSignature.DataCase, async: false

  import Mox

  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification
  alias CheckSignature.Verification.{MockSource, Ruling}

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    stub(MockSource, :name, fn -> "Mock court" end)
    :ok
  end

  test "a match yields :found and is cached (source hit only once)" do
    signature = Signature.new("II CSK 1/20")

    expect(MockSource, :lookup, 1, fn _ ->
      {:matched, %Ruling{signature: "II CSK 1/20", url: "https://example.test/1"}}
    end)

    assert %{status: :found, matches: [%{source: "Mock court"}]} = Verification.check(signature)
    # Second check is served from the cache — no further lookup (expect count = 1).
    assert %{status: :found} = Verification.check(signature)
  end

  test "confirmed absence yields :not_found and is cached" do
    signature = Signature.new("II CSK 2/20")
    expect(MockSource, :lookup, 1, fn _ -> :confirmed_absent end)

    assert %{status: :not_found} = Verification.check(signature)
    assert %{status: :not_found} = Verification.check(signature)
  end

  test "an errored source yields :inconclusive and is NOT cached (re-checked)" do
    signature = Signature.new("II CSK 3/20")
    # Two lookups expected precisely because inconclusive results are never cached.
    expect(MockSource, :lookup, 2, fn _ -> {:errored, :timeout} end)

    assert %{status: :inconclusive} = Verification.check(signature)
    assert %{status: :inconclusive} = Verification.check(signature)
  end

  test "a raised exception in a source is contained as an errored outcome" do
    signature = Signature.new("II CSK 4/20")
    expect(MockSource, :lookup, fn _ -> raise "portal exploded" end)

    assert %{status: :inconclusive} = Verification.check(signature)
  end
end
