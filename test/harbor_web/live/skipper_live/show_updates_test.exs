defmodule HarborWeb.SkipperLive.ShowUpdatesTest do
  use HarborWeb.ConnCase

  import Harbor.SkipperFixtures
  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    skipper = skipper_fixture()
    conn = init_test_session(conn, %{browser_session_id: skipper.browser_session.id})

    Map.put(skipper, :conn, conn)
  end

  test "refreshes task results after a run status broadcast", %{
    conn: conn,
    prompt: prompt,
    run: run
  } do
    {:ok, view, _html} = live(conn, ~p"/skipper/#{prompt.id}")

    refute has_element?(view, "#skipper-result")

    response_task = response_task_fixture(run)
    analysis_task_fixture(run)
    synthesize_task = synthesize_task_fixture(run)

    Gust.PubSub.broadcast_run_status(run.id, :running, synthesize_task.id)

    assert has_element?(view, "#response_tasks-#{response_task.id}")
    assert has_element?(view, "#analysis-consensus")
    assert has_element?(view, "#skipper-result")
    assert has_element?(view, "#skipper-results-status[data-status=succeeded]")
  end
end
