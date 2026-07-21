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
    field :url, :string

    timestamps(type: :utc_datetime)
  end
end
