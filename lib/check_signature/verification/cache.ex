defmodule CheckSignature.Verification.Cache do
  @moduledoc """
  Durable Signature -> Verdict cache backed by Postgres (ADR 0004).

  Only *settled* Verdicts are cached — `:found` and `:not_found`. An
  `:inconclusive` Verdict reflects a transient portal problem, so caching it
  would freeze an outage into a false answer; we deliberately never store it.
  Entries expire after the configured TTL so a corrected portal, or a newly
  published Ruling, is eventually picked up.
  """

  import Ecto.Query

  alias CheckSignature.Repo
  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification.{CachedVerdict, Ruling, Verdict}

  @doc "Returns a cached, non-expired Verdict for the Signature, or `:miss`."
  @spec fetch(Signature.t()) :: {:ok, Verdict.t()} | :miss
  def fetch(%Signature{normalized: normalized} = signature) do
    now = DateTime.utc_now()

    query =
      from c in CachedVerdict,
        where: c.signature == ^normalized and c.expires_at > ^now

    case Repo.one(query) do
      nil -> :miss
      %CachedVerdict{} = row -> {:ok, rehydrate(row, signature)}
    end
  end

  @doc """
  Batch variant of `fetch/1`: resolves many Signatures in a single query,
  returning a map of `normalized => Verdict` for the ones that hit a cached,
  non-expired entry. Signatures not present in the map are cache misses.

  Callers verifying a whole Document use this to collapse what would otherwise
  be one SELECT per Signature into one SELECT per Document.
  """
  @spec fetch_many([Signature.t()]) :: %{optional(String.t()) => Verdict.t()}
  def fetch_many([]), do: %{}

  def fetch_many(signatures) do
    now = DateTime.utc_now()
    by_normalized = Map.new(signatures, &{&1.normalized, &1})

    query =
      from c in CachedVerdict,
        where: c.signature in ^Map.keys(by_normalized) and c.expires_at > ^now

    query
    |> Repo.all()
    |> Map.new(fn %CachedVerdict{signature: normalized} = row ->
      {normalized, rehydrate(row, Map.fetch!(by_normalized, normalized))}
    end)
  end

  @doc """
  Persists a settled Verdict. `:inconclusive` Verdicts are ignored (returned
  as-is) so outages are never cached.
  """
  @spec put(Verdict.t()) :: Verdict.t()
  def put(%Verdict{status: status} = verdict) when status in [:found, :not_found] do
    attrs = %{
      signature: verdict.signature.normalized,
      status: Atom.to_string(status),
      data: serialize(verdict),
      expires_at: expires_at()
    }

    %CachedVerdict{}
    |> CachedVerdict.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:status, :data, :expires_at, :updated_at]},
      conflict_target: :signature
    )

    verdict
  end

  def put(%Verdict{} = verdict), do: verdict

  defp serialize(%Verdict{} = verdict) do
    %{
      "checked" => verdict.checked,
      "matches" =>
        Enum.map(verdict.matches, fn %{source: source, ruling: %Ruling{} = r} ->
          %{
            "source" => source,
            "ruling" => %{
              "signature" => r.signature,
              "url" => r.url,
              "court" => r.court,
              "date" => r.date,
              "title" => r.title
            }
          }
        end)
    }
  end

  defp rehydrate(%CachedVerdict{} = row, %Signature{} = signature) do
    data = row.data || %{}

    %Verdict{
      signature: signature,
      status: String.to_existing_atom(row.status),
      checked: Map.get(data, "checked", []),
      errored: [],
      matches:
        data
        |> Map.get("matches", [])
        |> Enum.map(fn m ->
          r = Map.get(m, "ruling", %{})

          %{
            source: Map.get(m, "source"),
            ruling: %Ruling{
              signature: Map.get(r, "signature"),
              url: Map.get(r, "url"),
              court: Map.get(r, "court"),
              date: Map.get(r, "date"),
              title: Map.get(r, "title")
            }
          }
        end)
    }
  end

  defp expires_at do
    ttl =
      :check_signature
      |> Application.get_env(CheckSignature.Verification, [])
      |> Keyword.get(:cache_ttl_seconds, 604_800)

    DateTime.utc_now()
    |> DateTime.add(ttl, :second)
    |> DateTime.truncate(:second)
  end
end
