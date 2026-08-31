defmodule Harbor.Prompts.Prompt do
  @moduledoc """
  A prompt submitted by an anonymous browser and executed by a Gust run.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Harbor.BrowserSessions.BrowserSession

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "prompts" do
    field :content, :string
    field :gust_run_id, :integer
    field :notification_email, :string
    field :public, :boolean, default: false

    belongs_to :browser_session, BrowserSession

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(prompt, attrs) do
    prompt
    |> form_changeset(attrs)
    |> validate_required([:gust_run_id, :browser_session_id])
    |> validate_number(:gust_run_id, greater_than: 0)
    |> check_constraint(:content, name: :prompts_content_not_blank)
    |> unique_constraint(:gust_run_id)
    |> foreign_key_constraint(:browser_session_id)
  end

  @doc """
  Builds a changeset for the user-editable prompt fields.
  """
  def form_changeset(prompt, attrs) do
    prompt
    |> cast(attrs, [:content])
    |> validate_required([:content])
  end

  @doc """
  Builds a changeset for a prompt completion notification email.
  """
  def notification_changeset(prompt, attrs) do
    prompt
    |> cast(attrs, [:notification_email])
    |> update_change(:notification_email, &normalize_notification_email/1)
    |> validate_required([:notification_email])
    |> validate_length(:notification_email, max: 254)
    |> validate_format(:notification_email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/,
      message: "must be a valid email address"
    )
  end

  defp normalize_notification_email(email) when is_binary(email), do: String.trim(email)
  defp normalize_notification_email(email), do: email
end
