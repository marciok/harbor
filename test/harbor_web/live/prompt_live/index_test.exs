defmodule HarborWeb.PromptLive.IndexTest do
  use HarborWeb.ConnCase

  import Harbor.PromptsFixtures
  import Phoenix.LiveViewTest

  alias Harbor.BrowserSessions
  alias Harbor.Prompts

  setup %{conn: conn} do
    {:ok, browser_session} = BrowserSessions.create_browser_session()
    conn = init_test_session(conn, %{browser_session_id: browser_session.id})

    %{browser_session: browser_session, conn: conn}
  end

  test "renders the streamed empty state", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/prompts")

    assert has_element?(view, "#prompts-runs[phx-update=stream]")
    assert has_element?(view, "#prompts-empty")
    assert has_element?(view, "#primary-navigation a[href='/skipper']")

    assert has_element?(
             view,
             "#mobile-navigation-button[aria-controls=app-sidebar][aria-expanded=false]"
           )

    assert has_element?(view, "#mobile-navigation-close[aria-label='Close navigation']")
    assert has_element?(view, "#mobile-navigation-backdrop[aria-label='Close navigation']")
    assert has_element?(view, "#app-sidebar[aria-label='Application navigation']")
    assert has_element?(view, "#sidebar-sessions")
  end

  test "lists owned prompts while limiting the sidebar to the latest ten", %{
    browser_session: browser_session,
    conn: conn
  } do
    prompts =
      for number <- 1..11 do
        create_prompt(browser_session.id, "Prompt #{number}")
      end

    {:ok, other_browser_session} = BrowserSessions.create_browser_session()
    other_prompt = create_prompt(other_browser_session.id, "Another browser's prompt")

    {:ok, view, _html} = live(conn, ~p"/prompts")

    for prompt <- prompts do
      assert has_element?(view, "#all_prompts-#{prompt.id}[href='/skipper/#{prompt.id}']")
    end

    oldest_prompt = List.first(prompts)
    newest_prompt = List.last(prompts)

    refute has_element?(view, "#all_prompts-#{other_prompt.id}")
    refute has_element?(view, "#sidebar-session-#{oldest_prompt.id}")
    assert has_element?(view, "#sidebar-session-#{newest_prompt.id}")
  end

  defp create_prompt(browser_session_id, content) do
    {:ok, prompt} =
      Prompts.create_prompt(browser_session_id, unique_gust_run_id(), %{
        content: content
      })

    prompt
  end
end
