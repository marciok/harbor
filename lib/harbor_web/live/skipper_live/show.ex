defmodule HarborWeb.SkipperLive.Show do
  use HarborWeb, :live_view
  alias Gust.Flows
  alias Harbor.Prompts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} prompts={@recent_prompts} current_prompt_id={@current_prompt_id}>
      <.header>
        Skipper
        <:subtitle>
          Review the panel's responses, analysis, and final synthesized answer.
        </:subtitle>
      </.header>

      <aside :if={@content} id="skipper-prompt-context" class="skipper-prompt-context">
        <div class="skipper-prompt-context__icon">
          <.icon name="hero-chat-bubble-bottom-center-text" class="size-5" />
        </div>
        <div>
          <h2 class="skipper-prompt-context__label">Prompt</h2>
          <p id="prompt-content" class="skipper-prompt-context__text">{@content}</p>
        </div>
      </aside>

      <div
        id="skipper-workflow"
        class="skipper-workflow"
      >
        <section
          id="skipper-sources"
          class={["skipper-stage", @models_used == 0 && "opacity-50"]}
          aria-labelledby="skipper-sources-heading"
        >
          <header class="skipper-stage__header">
            <span class="skipper-stage__number">01</span>
            <div class="min-w-0 flex-1">
              <div class="skipper-stage__title-row">
                <h2 id="skipper-sources-heading" class="skipper-stage__title">Sources</h2>
                <span :if={@models_used > 0} class="skipper-stage__count">
                  {@models_used} models
                </span>
              </div>
              <p class="skipper-stage__description">Independent responses from the model panel.</p>
            </div>
          </header>

          <div
            id="skipper-sources-list"
            class="skipper-stage__body"
            phx-update="stream"
          >
            <.stage_empty id="skipper-sources-empty" icon="hero-circle-stack" />

            <.source_card
              :for={{dom_id, task} <- @streams.response_tasks}
              id={dom_id}
              source={task}
            />
          </div>
        </section>

        <section
          id="skipper-analysis"
          class={["skipper-stage", is_nil(@analysis_task) && "opacity-50"]}
          aria-labelledby="skipper-analysis-heading"
        >
          <header class="skipper-stage__header">
            <span class="skipper-stage__number">02</span>
            <div class="min-w-0 flex-1">
              <div class="skipper-stage__title-row">
                <h2 id="skipper-analysis-heading" class="skipper-stage__title">Analysis</h2>
                <.task_status id="skipper-analysis-status" task={@analysis_task} />
              </div>
              <p class="skipper-stage__description">
                Agreements, conflicts, gaps, and unique insights across sources.
              </p>
            </div>
          </header>

          <div id="skipper-analysis-list" class="skipper-stage__body">
            <.stage_empty id="skipper-analysis-empty" icon="hero-magnifying-glass" />

            <.analysis_card
              :for={{title, items} <- @analysis_result}
              items={items}
              title={title}
            />
          </div>
        </section>

        <section
          id="skipper-results"
          class={["skipper-stage", is_nil(@synthesize_task) && "opacity-50"]}
          aria-labelledby="skipper-results-heading"
        >
          <header class="skipper-stage__header">
            <span class="skipper-stage__number">
              <.icon name="hero-arrows-pointing-in" class="sidebar__icon" />
            </span>

            <div class="min-w-0 flex-1">
              <div class="skipper-stage__title-row">
                <h2 id="skipper-results-heading" class="skipper-stage__title">Results</h2>
                <.task_status id="skipper-results-status" task={@synthesize_task} />
              </div>
            </div>
          </header>

          <div id="skipper-results-content" class="skipper-stage__body">
            <.panel_model
              model={@synthesizer}
              id="model-synthesizer-result"
              removable={false}
              selected={true}
            />
            <article
              :if={@synthesize_result}
              id="skipper-result"
              class="skipper-result"
            >
              <.markdown
                id="skipper-result-markdown"
                content={@synthesize_result}
              />
            </article>
          </div>
        </section>

        <div id="skipper-try-again-actions" class="flex flex-wrap justify-end gap-2">
          <.button
            :if={@owner? && @synthesize_result}
            id="skipper-toggle-sharing"
            phx-click={
              if(@prompt.public,
                do: "toggle-sharing",
                else:
                  JS.push("toggle-sharing")
                  |> JS.dispatch("harbor:copy",
                    detail: %{text: url(~p"/skipper/#{@prompt.id}")}
                  )
              )
            }
          >
            <.icon
              name={if(@prompt.public, do: "hero-x-mark", else: "hero-share")}
              class="size-4"
            />
            {if(@prompt.public, do: "Stop sharing", else: "Share")}
          </.button>

          <.button
            :if={@synthesize_result}
            id="skipper-try-again"
            variant="primary"
            navigate={~p"/skipper"}
          >
            <.icon name="hero-sparkles" class="size-4" /> New prompt!
          </.button>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"prompt_id" => prompt_id}, %{"browser_session_id" => browser_session_id}, socket) do
    prompt = Prompts.get_accessible_prompt(browser_session_id, prompt_id)

    if prompt do
      run = Flows.get_run!(prompt.gust_run_id)

      if connected?(socket) do
        Gust.PubSub.subscribe_run(run.id)
      end

      recent_prompts = Prompts.list_prompts(browser_session_id, limit: 10)

      {:ok,
       socket
       |> assign(:page_title, "Show Skipper")
       |> assign(:browser_session_id, browser_session_id)
       |> assign(:owner?, prompt.browser_session_id == browser_session_id)
       |> assign(:prompt, prompt)
       |> assign(:recent_prompts, recent_prompts)
       |> assign(:content, prompt.content)
       |> assign(:current_prompt_id, prompt.id)
       |> assign(:synthesizer, run.params["synthesizer"])
       |> assign_tasks_results(run.id)}
    else
      {:ok, socket |> push_navigate(to: ~p"/") |> put_flash(:error, "This prompt is private!")}
    end
  end

  @impl true
  def handle_event("toggle-sharing", _params, %{assigns: %{owner?: true}} = socket) do
    public = !socket.assigns.prompt.public

    {:ok, prompt} =
      Prompts.set_public(socket.assigns.browser_session_id, socket.assigns.prompt.id, public)

    message = if public, do: "URL copied", else: "Sharing stopped"

    {:noreply,
     socket
     |> assign(:prompt, prompt)
     |> put_flash(:info, message)}
  end

  defp assign_tasks_results(socket, run_id) do
    response_tasks = get_responses_task(run_id)
    analysis_task = Flows.get_task_by_name_run("judge_analysis", run_id)
    synthesize_task = Flows.get_task_by_name_run("synthesize", run_id)

    socket
    |> assign(
      analysis_result: task_result(analysis_task, "analysis", %{}),
      analysis_task: analysis_task,
      models_used: length(response_tasks),
      synthesize_result: task_result(synthesize_task, "answer", nil),
      synthesize_task: synthesize_task
    )
    |> stream(:response_tasks, response_tasks)
  end

  defp get_responses_task(run_id) do
    Flows.get_tasks_by_name("get_responses", run_id)
  end

  defp task_result(%{result: result}, key, default) when is_map(result),
    do: Map.get(result, key, default)

  defp task_result(_task, _key, default), do: default

  @impl true
  def handle_info(
        {:dag, :run_status, %{run_id: run_id, status: _status, task_id: _task_id}},
        socket
      ) do
    {:noreply,
     socket
     |> assign_tasks_results(run_id)}
  end
end
