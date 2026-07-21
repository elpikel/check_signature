defmodule CheckSignature.Rulings.Ruling do
  @moduledoc """
  Ecto schema for the harvested Rulings index (`rulings` table).

  One row per `{source, signature_normalized}` — the durable, locally-searchable
  record that a court Ruling with this Signature exists, populated by the
  background harvesters. Distinct from `CheckSignature.Verification.Ruling`, the
  in-flight struct a live Source lookup returns. Holds only public court data
  (ADR 0003).
  """

  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "rulings" do
    field :source, :string
    field :signature_normalized, :string
    field :signature_raw, :string
    field :url, :string
    field :court, :string
    field :title, :string
    field :decided_on, :date

    timestamps(type: :utc_datetime)
  end
end
