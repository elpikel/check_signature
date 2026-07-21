defmodule CheckSignature.Repo.Migrations.AddObanJobs do
  use Ecto.Migration

  def up, do: Oban.Migration.up(version: 14)

  # Roll back to the base version rather than dropping the schema outright.
  def down, do: Oban.Migration.down(version: 1)
end
