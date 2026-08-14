defmodule HarborWeb.SkipperLive.PromptTest do
  use HarborWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Gust.Flows
  alias Harbor.BrowserSessions
  alias HarborWeb.SkipperLive.Prompt, as: PromptLive

  setup %{conn: conn} do
    {:ok, browser_session} = BrowserSessions.create_browser_session()

    Flows.get_dag_by_name("fetch_models")
    |> Ecto.Changeset.change(name: "fetch_models_seeded")
    |> Gust.Repo.update!()

    {:ok, dag} = Flows.create_dag(%{name: "fetch_models"})

    conn = init_test_session(conn, %{browser_session_id: browser_session.id})

    %{conn: conn, dag: dag}
  end

  test "renders the gateway setup state when no models are available", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/skipper")

    assert has_element?(view, "#skipper-gateway-status[role=status]")
    assert has_element?(view, "#skipper-gateway-status-title")
    assert has_element?(view, "button#skipper-load-models:not([disabled])")
    assert has_element?(view, "#skipper > header p.text-slate-600")

    refute has_element?(view, "#skipper-gateway-availability")
    refute has_element?(view, "#skipper-current-balance")
  end

  test "renders model availability and balance for a ready gateway", %{conn: conn, dag: dag} do
    {:ok, run} = Flows.create_run(%{dag_id: dag.id, status: :succeeded})

    create_task(run.id, "fetch", %{
      "gust_task_items" => [
        %{
          "name" => "Claude Fable 5",
          "owner" => "anthropic",
          "slug" => "anthropic/claude-fable-5"
        },
        %{
          "name" => "GPT 5.5",
          "owner" => "openai",
          "slug" => "openai/gpt-5.5"
        }
      ]
    })

    create_task(run.id, "get_budget", %{"balance" => "24.56"})

    {:ok, view, _html} = live(conn, ~p"/skipper")

    assert has_element?(view, "#skipper-gateway-status[role=status]")
    assert has_element?(view, "#skipper-current-balance")

    assert has_element?(
             view,
             "#skipper-synthesizer-button img[src='/images/model-providers/anthropic.svg']"
           )

    assert has_element?(
             view,
             "input#skipper-synthesizer-model[type=hidden][value='anthropic/claude-fable-5']"
           )

    assert has_element?(
             view,
             "[id='skipper-add-model-option-openai/gpt-5.5'] img[src='/images/model-providers/openai.svg']"
           )

    refute has_element?(view, "#skipper-load-models")
  end

  test "selects a synthesizer from the logo menu", %{conn: conn, dag: dag} do
    {:ok, run} = Flows.create_run(%{dag_id: dag.id, status: :succeeded})

    create_task(run.id, "fetch", %{
      "gust_task_items" => [
        %{
          "name" => "Claude Fable 5",
          "owner" => "anthropic",
          "slug" => "anthropic/claude-fable-5"
        },
        %{"name" => "GPT 5.5", "owner" => "openai", "slug" => "openai/gpt-5.5"}
      ]
    })

    create_task(run.id, "get_budget", %{"balance" => "24.56"})

    {:ok, view, _html} = live(conn, ~p"/skipper")

    view
    |> element("[id='skipper-synthesizer-option-openai/gpt-5.5']")
    |> render_click()

    assert has_element?(
             view,
             "input#skipper-synthesizer-model[value='openai/gpt-5.5']"
           )

    assert has_element?(
             view,
             "#skipper-synthesizer-button img[src='/images/model-providers/openai.svg']"
           )

    assert has_element?(
             view,
             "[id='skipper-synthesizer-option-openai/gpt-5.5'] .hero-check"
           )
  end

  test "only reports a run-level failure for the active model-loading run" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        flash: %{},
        loading_models: true,
        load_models_run_id: 42
      },
      private: %{live_temp: %{}}
    }

    task_failure =
      {:dag, :run_status, %{run_id: 42, status: :failed, task_id: 7}}

    {:noreply, socket} = PromptLive.handle_info(task_failure, socket)

    assert socket.assigns.loading_models
    assert socket.assigns.load_models_run_id == 42
    assert socket.assigns.flash == %{}

    run_failure =
      {:dag, :run_status, %{run_id: 42, status: :failed, task_id: nil}}

    {:noreply, socket} = PromptLive.handle_info(run_failure, socket)

    refute socket.assigns.loading_models
    assert socket.assigns.load_models_run_id == nil
    assert socket.assigns.flash["error"] == "Unable to load models. Please try again."
  end

  defp create_task(run_id, name, result) do
    {:ok, task} =
      Flows.create_task(%{
        error: %{},
        name: name,
        params: %{},
        result: result,
        run_id: run_id,
        status: :succeeded
      })

    task
  end
end
