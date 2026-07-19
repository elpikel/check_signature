defmodule CheckSignature.Repo.Migrations.CreateCachedVerdicts do
  use Ecto.Migration

  # Durable Signature -> Verdict cache (ADR 0004). Holds only public court
  # references — never user-submitted Document text (ADR 0003).
  def change do
    create table(:cached_verdicts) do
      add :signature, :string, null: false
      add :status, :string, null: false
      add :data, :map, null: false, default: %{}
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:cached_verdicts, [:signature])
    create index(:cached_verdicts, [:expires_at])
  end
end
