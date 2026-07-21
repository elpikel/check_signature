defmodule CheckSignature.Repo.Migrations.CreateRulings do
  use Ecto.Migration

  # Harvested positive index of court Rulings (one row per Source + Signature).
  # Populated by the background harvesters; read on the request path to answer
  # "does this Signature exist?" without live-scraping. Public court data only
  # (ADR 0003) — never user-submitted Document text.
  def change do
    create table(:rulings) do
      add :source, :string, null: false
      add :signature_normalized, :string, null: false
      add :signature_raw, :string, null: false
      add :url, :string, null: false
      add :court, :string
      add :title, :string
      add :decided_on, :date

      timestamps(type: :utc_datetime)
    end

    # One row per (source, signature) — the upsert conflict target.
    create unique_index(:rulings, [:source, :signature_normalized])
    # Cross-source lookup by signature on the request path.
    create index(:rulings, [:signature_normalized])
    # Incremental-harvest cursor scans newest-first within a source.
    create index(:rulings, [:source, :decided_on])
  end
end
