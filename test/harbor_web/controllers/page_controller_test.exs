defmodule HarborWeb.PageControllerTest do
  use HarborWeb.ConnCase

  alias Harbor.BrowserSessions
  alias Harbor.BrowserSessions.BrowserSession

  test "GET / renders the Harbor home page", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    document = LazyHTML.from_document(html)

    assert document |> LazyHTML.query("#home-page") |> Enum.count() == 1
    assert document |> LazyHTML.query("#home-open-skipper[href='/skipper']") |> Enum.count() == 1
    assert document |> LazyHTML.query("#how-it-works .home-step") |> Enum.count() == 3

    assert document
           |> LazyHTML.query(
             "#home-star-gust[href='https://github.com/marciok/gust'][target='_blank'][rel='noopener noreferrer']"
           )
           |> Enum.count() == 1

    assert document
           |> LazyHTML.query("link[rel='icon'][href='/gust/images/gust-logo.png']")
           |> Enum.count() == 1

    assert document |> LazyHTML.query("#app-sidebar") |> Enum.empty?()
    assert document |> LazyHTML.query("#sidebar-sessions") |> Enum.empty?()
    assert document |> LazyHTML.query("#mobile-app-bar") |> Enum.empty?()
    assert document |> LazyHTML.query("#mobile-navigation-backdrop") |> Enum.empty?()
  end

  test "assigns a persistent browser session", %{conn: conn} do
    conn = get(conn, ~p"/")
    browser_session_id = get_session(conn, :browser_session_id)

    assert %BrowserSession{id: ^browser_session_id} =
             BrowserSessions.get_browser_session(browser_session_id)

    assert conn.assigns.browser_session.id == browser_session_id
    assert conn.resp_cookies["_harbor_key"].max_age == 31_536_000

    conn =
      conn
      |> recycle()
      |> get(~p"/")

    assert get_session(conn, :browser_session_id) == browser_session_id
  end
end
