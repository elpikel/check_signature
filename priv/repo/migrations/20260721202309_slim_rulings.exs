defmodule CheckSignature.Repo.Migrations.SlimRulings do
  use Ecto.Migration

  # We only need to answer "does this signature exist, and where's the link?".
  # Drop everything we never read: signature_raw, court, title, decided_on.
  def up do
    drop index(:rulings, [:source, :decided_on])

    alter table(:rulings) do
      remove :signature_raw
      remove :court
      remove :title
      remove :decided_on
    end
  end

  def down do
    alter table(:rulings) do
      add :signature_raw, :string
      add :court, :string
      add :title, :string
      add :decided_on, :date
    end

    create index(:rulings, [:source, :decided_on])
  end
end
