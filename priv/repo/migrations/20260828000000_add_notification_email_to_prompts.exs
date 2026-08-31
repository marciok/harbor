defmodule Harbor.Repo.Migrations.AddNotificationEmailToPrompts do
  use Ecto.Migration

  def change do
    alter table(:prompts) do
      add :notification_email, :string
    end
  end
end
