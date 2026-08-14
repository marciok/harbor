defmodule Harbor.BrowserSessions do
  @moduledoc """
  Manages the persistent identities assigned to anonymous browsers.
  """

  alias Harbor.BrowserSessions.BrowserSession
  alias Harbor.Repo

  @doc """
  Returns a browser session by ID, or `nil` when the ID is invalid or unknown.
  """
  def get_browser_session(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} -> Repo.get(BrowserSession, id)
      :error -> nil
    end
  end

  def get_browser_session(_id), do: nil

  @doc """
  Creates a persistent browser session with a generated UUID.
  """
  def create_browser_session do
    %BrowserSession{}
    |> Repo.insert()
  end

  @doc """
  Returns the identified browser session, creating a new one when necessary.
  """
  def get_or_create_browser_session(id) do
    case get_browser_session(id) do
      %BrowserSession{} = browser_session -> {:ok, browser_session}
      nil -> create_browser_session()
    end
  end
end
