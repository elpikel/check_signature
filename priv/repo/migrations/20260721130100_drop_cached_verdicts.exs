defmodule CheckSignature.Repo.Migrations.DropCachedVerdicts do
  use Ecto.Migration

  # Verification is now answered solely from the harvested `rulings` index, so the
  # settled-Verdict cache (ADR 0004) is retired. `down/0` recreates it to match the
  # original create migration, keeping the rollback path intact.
  def up do
    drop table(:cached_verdicts)
  end

  def down do
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
