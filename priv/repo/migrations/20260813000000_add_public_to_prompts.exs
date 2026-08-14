defmodule Harbor.Repo.Migrations.AddPublicToPrompts do
  use Ecto.Migration

  def change do
    alter table(:prompts) do
      add :public, :boolean, null: false, default: false
    end
  end
end
