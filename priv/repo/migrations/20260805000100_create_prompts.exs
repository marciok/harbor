defmodule Harbor.Repo.Migrations.CreatePrompts do
  use Ecto.Migration

  def change do
    create table(:prompts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :text, null: false
      add :gust_run_id, :bigint, null: false

      add :browser_session_id,
          references(:browser_sessions, type: :binary_id, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create constraint(:prompts, :prompts_content_not_blank,
             check: "char_length(btrim(content)) > 0"
           )

    create unique_index(:prompts, [:gust_run_id])
    create index(:prompts, [:browser_session_id, :inserted_at])
  end
end
