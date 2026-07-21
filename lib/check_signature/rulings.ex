defmodule CheckSignature.Rulings do
  @moduledoc """
  The harvested Rulings index: the local, durable answer to "does a Ruling with
  this Signature exist?".

  Populated by `CheckSignature.Verification.HarvestWorker` (background), read on
  the request path by `CheckSignature.Verification` so a check that hits the index
  never scrapes a portal. Writes are idempotent upserts keyed on
  `{source, signature_normalized}`, so re-harvesting the same Ruling is a no-op
  beyond refreshing `updated_at`.
  """

  import Ecto.Query

  alias CheckSignature.Repo
  alias CheckSignature.Rulings.Ruling
  alias CheckSignature.Signatures.Signature

  @doc """
  Idempotently upserts harvested entries. Each entry is a map with a raw
  `:signature` string plus `:url` and (optionally) `:court`, `:title`,
  `:decided_on`; `:source` is the Source key. Returns `{count, nil}`.
  """
  @spec upsert_all(String.t(), [map()]) :: {non_neg_integer(), nil}
  def upsert_all(_source, []), do: {0, nil}

  def upsert_all(source, entries) when is_binary(source) and is_list(entries) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    rows =
      Enum.map(entries, fn entry ->
        raw = to_string(entry[:signature] || entry[:signature_raw])

        %{
          source: source,
          signature_normalized: Signature.normalize(raw),
          signature_raw: raw,
          url: entry[:url],
          court: entry[:court],
          title: entry[:title],
          decided_on: entry[:decided_on],
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(Ruling, rows,
      on_conflict: {:replace, [:signature_raw, :url, :court, :title, :decided_on, :updated_at]},
      conflict_target: [:source, :signature_normalized]
    )
  end

  @doc "All harvested Rulings whose normalized Signature is in the given list (any Source)."
  @spec lookup_many([String.t()]) :: [Ruling.t()]
  def lookup_many([]), do: []

  def lookup_many(normalized_list) when is_list(normalized_list) do
    Repo.all(from r in Ruling, where: r.signature_normalized in ^normalized_list)
  end

  @doc "Harvested Rulings for a single normalized Signature (any Source)."
  @spec lookup(String.t()) :: [Ruling.t()]
  def lookup(normalized) when is_binary(normalized), do: lookup_many([normalized])

  @doc """
  Of `normalized_list`, the subset already stored for `source`, as a MapSet.
  Drives the harvest stop condition: a page whose Signatures are all in this set
  is fully-known, i.e. we've caught up to the previous run.
  """
  @spec existing_for_source(String.t(), [String.t()]) :: MapSet.t()
  def existing_for_source(_source, []), do: MapSet.new()

  def existing_for_source(source, normalized_list) when is_binary(source) do
    from(r in Ruling,
      where: r.source == ^source and r.signature_normalized in ^normalized_list,
      select: r.signature_normalized
    )
    |> Repo.all()
    |> MapSet.new()
  end
end
