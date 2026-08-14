defmodule Harbor.Repo.Migrations.CreateBrowserSessions do
  use Ecto.Migration

  def change do
    create table(:browser_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      timestamps(type: :utc_datetime)
    end
  end
end
