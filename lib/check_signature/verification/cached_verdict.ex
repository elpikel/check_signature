defmodule CheckSignature.Verification.CachedVerdict do
  @moduledoc """
  Ecto schema for the durable Signature -> Verdict cache (ADR 0004).

  `signature` is the normalized form. `data` is a jsonb snapshot of the matches
  and the Sources checked, enough to rebuild a `Verdict` without re-scraping. Only
  public court references live here — never Document text (ADR 0003).
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "cached_verdicts" do
    field :signature, :string
    field :status, :string
    field :data, :map, default: %{}
    field :expires_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(cached_verdict, attrs) do
    cached_verdict
    |> cast(attrs, [:signature, :status, :data, :expires_at])
    |> validate_required([:signature, :status, :expires_at])
    |> validate_inclusion(:status, ["found", "not_found"])
    |> unique_constraint(:signature)
  end
end
