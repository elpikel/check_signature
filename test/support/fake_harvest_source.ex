defmodule CheckSignature.Verification.Sources.FakeHarvestSource do
  @moduledoc """
  A scripted, network-free harvestable Source for testing
  `CheckSignature.Verification.HarvestWorker`.

  Paginates deterministically off the cursor (no process state): three pages of
  two Rulings each, newest-first, then `:done`. Register it in a test with

      Application.put_env(:check_signature, :extra_harvest_sources,
        %{"fake" => __MODULE__})
  """

  @behaviour CheckSignature.Verification.Source

  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification.Verdict

  @pages %{
    1 => [{"II CSK 1/20", 1}, {"II CSK 2/20", 2}],
    2 => [{"II CSK 3/20", 3}, {"II CSK 4/20", 4}],
    3 => [{"II CSK 5/20", 5}, {"II CSK 6/20", 6}]
  }

  @impl true
  def name, do: "Fake court"

  @impl true
  @spec lookup(Signature.t()) :: Verdict.source_outcome()
  def lookup(%Signature{}), do: :confirmed_absent

  @impl true
  def harvest_page(cursor) do
    page = page_number(cursor)

    case Map.get(@pages, page) do
      nil -> {[], :done}
      rulings -> {Enum.map(rulings, &entry/1), %{"page" => page + 1}}
    end
  end

  defp page_number(nil), do: 1
  defp page_number(%{"page" => n}), do: n

  defp entry({sig, id}) do
    %{signature: sig, url: "https://fake.test/#{id}", court: "Fake", title: "Wyrok #{sig}"}
  end
end
