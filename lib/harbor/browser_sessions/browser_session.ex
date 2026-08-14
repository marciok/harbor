defmodule Harbor.BrowserSessions.BrowserSession do
  @moduledoc """
  A persistent identity for an anonymous browser.

  The identifier is stored in Harbor's signed session cookie and can be used to
  scope records, such as prompts, to the browser that created them.
  """

  use Ecto.Schema

  alias Harbor.Prompts.Prompt

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "browser_sessions" do
    has_many :prompts, Prompt

    timestamps(type: :utc_datetime)
  end
end
