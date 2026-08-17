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
           |> LazyHTML.query("link[rel='icon'][href='/images/gust/gust-logo.png']")
           |> Enum.count() == 1

    assert document
           |> LazyHTML.query("meta[name='description']")
           |> LazyHTML.attribute("content") ==
             [
               "Compare responses from multiple AI models and synthesize their strongest ideas into one answer."
             ]

    assert document
           |> LazyHTML.query("meta[property='og:title']")
           |> LazyHTML.attribute("content") == ["Model orchestration · Harbor"]

    assert document
           |> LazyHTML.query(
             "meta[property='og:image'][content$='/images/harbor-social-card.png']"
           )
           |> Enum.count() == 1

    assert document
           |> LazyHTML.query("meta[property='og:image:width'][content='1200']")
           |> Enum.count() == 1

    assert document
           |> LazyHTML.query("meta[property='og:image:height'][content='630']")
           |> Enum.count() == 1

    assert document
           |> LazyHTML.query("meta[name='twitter:card'][content='summary_large_image']")
           |> Enum.count() == 1

    assert document
           |> LazyHTML.query(
             "meta[name='twitter:image'][content$='/images/harbor-social-card.png']"
           )
           |> Enum.count() == 1

    [canonical_url] =
      document
      |> LazyHTML.query("link[rel='canonical']")
      |> LazyHTML.attribute("href")

    assert %URI{scheme: scheme, path: "/"} = URI.parse(canonical_url)
    assert scheme in ["http", "https"]

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

  test "serves the Gust logo from the public asset path", %{conn: conn} do
    conn = get(conn, ~p"/images/gust/gust-logo.png")

    assert response(conn, 200)
    assert get_resp_header(conn, "content-type") == ["image/png"]
  end

  test "serves the social preview image", %{conn: conn} do
    conn = get(conn, ~p"/images/harbor-social-card.png")

    assert response(conn, 200)
    assert get_resp_header(conn, "content-type") == ["image/png"]
  end
end
