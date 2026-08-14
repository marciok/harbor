defmodule Harbor.BrowserSessionsTest do
  use Harbor.DataCase, async: true

  alias Harbor.BrowserSessions
  alias Harbor.BrowserSessions.BrowserSession

  test "creates a persistent browser session with a UUID" do
    assert {:ok, %BrowserSession{} = browser_session} =
             BrowserSessions.create_browser_session()

    assert {:ok, _uuid} = Ecto.UUID.cast(browser_session.id)
    assert BrowserSessions.get_browser_session(browser_session.id) == browser_session
  end

  test "returns an existing browser session" do
    assert {:ok, browser_session} = BrowserSessions.create_browser_session()

    assert {:ok, same_browser_session} =
             BrowserSessions.get_or_create_browser_session(browser_session.id)

    assert same_browser_session.id == browser_session.id
  end

  test "replaces invalid and unknown identifiers" do
    unknown_id = Ecto.UUID.generate()

    assert {:ok, browser_session} =
             BrowserSessions.get_or_create_browser_session(unknown_id)

    refute browser_session.id == unknown_id

    assert {:ok, replacement} =
             BrowserSessions.get_or_create_browser_session("not-a-uuid")

    refute replacement.id == browser_session.id
  end
end
