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
end
