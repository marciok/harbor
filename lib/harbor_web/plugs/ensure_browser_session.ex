defmodule HarborWeb.Plugs.EnsureBrowserSession do
  @moduledoc """
  Ensures each browser has a persistent identity backed by the database.
  """

  import Plug.Conn

  alias Harbor.BrowserSessions

  @session_key :browser_session_id

  def init(opts), do: opts

  def call(conn, _opts) do
    current_id = get_session(conn, @session_key)
    {:ok, browser_session} = BrowserSessions.get_or_create_browser_session(current_id)

    conn
    |> maybe_put_browser_session_id(current_id, browser_session.id)
    |> assign(:browser_session, browser_session)
  end

  defp maybe_put_browser_session_id(conn, id, id), do: conn

  defp maybe_put_browser_session_id(conn, _current_id, browser_session_id) do
    put_session(conn, @session_key, browser_session_id)
  end
end
