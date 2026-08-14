defmodule HarborWeb.SkipperLive.ShowTest do
  use HarborWeb.ConnCase

  import Harbor.SkipperFixtures
  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    skipper = skipper_fixture()
    conn = init_test_session(conn, %{browser_session_id: skipper.browser_session.id})

    Map.put(skipper, :conn, conn)
  end

  test "renders the prompt and empty workflow stages", %{conn: conn, prompt: prompt} do
    {:ok, view, _html} = live(conn, ~p"/skipper/#{prompt.id}")

    assert has_element?(view, "#skipper-prompt-context #prompt-content")
    assert has_element?(view, "#skipper-workflow")
    assert has_element?(view, "#skipper-sources-list[phx-update=stream]")
    assert has_element?(view, "#skipper-sources-empty")
    assert has_element?(view, "#skipper-analysis-empty")
    assert has_element?(view, "#model-synthesizer-result.skipper-panel-model--selected")
    assert has_element?(view, "#skipper-try-again-actions")

    refute has_element?(view, "#skipper-analysis-status")
    refute has_element?(view, "#skipper-results-status")
    refute has_element?(view, "#skipper-result")
    refute has_element?(view, "#skipper-try-again")
    refute has_element?(view, "#skipper-toggle-sharing")
  end

  test "renders completed source, analysis, and synthesis tasks", %{
    conn: conn,
    prompt: prompt,
    run: run
  } do
    response_task = response_task_fixture(run)
    analysis_task_fixture(run)
    synthesize_task_fixture(run)

    {:ok, view, _html} = live(conn, ~p"/skipper/#{prompt.id}")

    assert has_element?(view, "#response_tasks-#{response_task.id}")

    assert has_element?(
             view,
             "#response_tasks-#{response_task.id}-status[data-status=succeeded]"
           )

    assert has_element?(view, "#skipper-analysis-status[data-status=succeeded]")
    assert has_element?(view, "#analysis-consensus .skipper-analysis-list__item")
    assert has_element?(view, "#skipper-results-status[data-status=succeeded]")
    assert has_element?(view, "#skipper-result #skipper-result-markdown")

    assert has_element?(
             view,
             "#model-synthesizer-result.skipper-panel-model--selected"
           )

    assert has_element?(
             view,
             "#model-synthesizer-result img[src='/images/model-providers/openai.svg']"
           )

    assert has_element?(view, "a#skipper-try-again[href='/skipper']")
    assert has_element?(view, "#skipper-toggle-sharing")
  end

  test "shares and stops sharing a completed result", %{
    conn: conn,
    prompt: prompt,
    run: run
  } do
    synthesize_task_fixture(run)
    {:ok, view, _html} = live(conn, ~p"/skipper/#{prompt.id}")

    view |> element("#skipper-toggle-sharing") |> render_click()

    assert has_element?(view, "#skipper-toggle-sharing")
    assert has_element?(view, "#flash-info", "URL copied")

    {:ok, other_browser_session} = Harbor.BrowserSessions.create_browser_session()
    other_conn = init_test_session(build_conn(), %{browser_session_id: other_browser_session.id})

    {:ok, shared_view, _html} = live(other_conn, ~p"/skipper/#{prompt.id}")
    assert has_element?(shared_view, "#skipper-result")
    refute has_element?(shared_view, "#skipper-toggle-sharing")

    view |> element("#skipper-toggle-sharing") |> render_click()

    assert has_element?(view, "#skipper-toggle-sharing")
    assert has_element?(view, "#flash-info", "Sharing stopped")

    assert_raise Ecto.NoResultsError, fn ->
      live(other_conn, ~p"/skipper/#{prompt.id}")
    end
  end

  test "does not render a prompt owned by another browser session", %{
    conn: conn,
    prompt: prompt
  } do
    {:ok, other_browser_session} = Harbor.BrowserSessions.create_browser_session()
    conn = init_test_session(conn, %{browser_session_id: other_browser_session.id})

    assert_raise Ecto.NoResultsError, fn ->
      live(conn, ~p"/skipper/#{prompt.id}")
    end
  end
end
