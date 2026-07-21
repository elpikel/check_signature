defmodule CheckSignature.Verification do
  @moduledoc """
  Verifying whether a Signature refers to a Ruling that actually exists.

  Answers come solely from the local `rulings` index, harvested in the background
  from the court portals (`CheckSignature.Verification.HarvestWorker`). A request
  never scrapes a portal:

    * the Signature is in the index → `:found`, linking the harvested Rulings;
    * the Signature is not in the index → `:inconclusive` ("couldn't confirm —
      check manually"). Never `:not_found`: the index is a harvested mirror that
      lags and, during backfill, is incomplete, so absence from it is *unknown*,
      not proof the Ruling was invented. This upholds the never-falsely-accuse
      contract (CONTEXT.md / the ADRs).

  Checking a whole Document — extraction, one Verdict per unique Signature — is
  done here; the per-Document cap lives in `CheckSignature.Signatures`.
  """

  alias CheckSignature.Rulings
  alias CheckSignature.Signatures
  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification.{Ruling, Sources, Verdict}

  @doc """
  Checks every Signature cited in a Document and returns one Verdict per unique
  Signature, in document order. One batched index read serves the whole Document.
  """
  @spec check_document(String.t()) :: [Verdict.t()]
  def check_document(document) when is_binary(document) do
    %{signatures: signatures} = Signatures.extract(document)
    index = index_lookup(signatures)

    Enum.map(signatures, fn %Signature{normalized: normalized} = signature ->
      case Map.get(index, normalized) do
        nil -> Verdict.inconclusive(signature)
        rows -> verdict_from_index(signature, rows)
      end
    end)
  end

  @doc "Returns the Verdict for a single Signature, from the harvested index."
  @spec check(Signature.t()) :: Verdict.t()
  def check(%Signature{normalized: normalized} = signature) do
    case Rulings.lookup(normalized) do
      [] -> Verdict.inconclusive(signature)
      rows -> verdict_from_index(signature, rows)
    end
  end

  defp index_lookup(signatures) do
    signatures
    |> Enum.map(& &1.normalized)
    |> Rulings.lookup_many()
    |> Enum.group_by(& &1.signature_normalized)
  end

  # Builds a `found` Verdict from harvested index rows, reusing `Verdict.derive/2`
  # by presenting each row as a `{source_name, {:matched, Ruling}}` outcome.
  defp verdict_from_index(%Signature{} = signature, rows) do
    outcomes =
      Enum.map(rows, fn row ->
        {source_name(row.source),
         {:matched,
          %Ruling{
            signature: row.signature_raw,
            url: row.url,
            court: row.court,
            date: row.decided_on && Date.to_iso8601(row.decided_on),
            title: row.title
          }}}
      end)

    Verdict.derive(signature, outcomes)
  end

  defp source_name(key) do
    case Sources.fetch(key) do
      {:ok, module} -> module.name()
      :error -> key
    end
  end
end
