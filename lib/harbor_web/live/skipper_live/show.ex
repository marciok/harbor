defmodule HarborWeb.SkipperLive.Show do
  use HarborWeb, :live_view
  alias Gust.Flows
  alias Harbor.Prompts
  alias Harbor.Prompts.Prompt

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
        <div class="min-w-0 flex-1">
          <h2 class="skipper-prompt-context__label">Prompt</h2>
          <p id="prompt-content" class="skipper-prompt-context__text">{@content}</p>
        </div>

        <.button
          :if={@owner? && (!@run_finished? || @prompt.notification_email)}
          id="skipper-notification-toggle"
          type="button"
          class="skipper-notification__trigger"
          phx-click="open_notification_modal"
          aria-expanded={@notification_form_open?}
          aria-controls="skipper-notification-modal"
          data-notification-set={if(@prompt.notification_email, do: "true", else: "false")}
        >
          <span :if={@prompt.notification_email} id="skipper-notification-saved">
            <.icon name="hero-check-circle" class="size-4 text-emerald-600" /> Notification is set
          </span>
          <span :if={!@prompt.notification_email}>
            <.icon name="hero-envelope" class="size-4" /> Notify when done
          </span>
        </.button>
      </aside>

      <dialog
        :if={@notification_form_open?}
        id="skipper-notification-modal"
        class="modal"
        open
        aria-modal="true"
        aria-labelledby="skipper-notification-modal-title"
        aria-describedby="skipper-notification-modal-description"
      >
        <div class="modal-box skipper-notification-modal__panel">
          <button
            id="skipper-notification-modal-close"
            type="button"
            class="skipper-notification-modal__close"
            phx-click="close_notification_modal"
            aria-label="Close notification form"
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>

          <header class="skipper-notification-modal__header">
            <span class="skipper-notification-modal__icon">
              <.icon name="hero-envelope" class="size-6" />
            </span>
            <div>
              <h2 id="skipper-notification-modal-title" class="skipper-notification-modal__title">
                {if(@run_finished?, do: "Your run is ready", else: "It can take a few minutes")}
              </h2>
              <p
                id="skipper-notification-modal-description"
                class="skipper-notification-modal__description"
              >
                {if(@run_finished?,
                  do: "There is no need to schedule another notification.",
                  else:
                    "Enter your email and we'll let you know as soon as Skipper finishes this run."
                )}
              </p>
            </div>
          </header>

          <div
            :if={@run_finished?}
            id="skipper-notification-finished"
            role="alert"
            class="alert alert-success mt-4"
          >
            <.icon
              name="hero-information-circle"
              class="h-6 w-6 shrink-0 stroke-current"
            />
            <span>Your run has already finished.</span>
          </div>

          <.form
            :if={!@run_finished?}
            for={@notification_form}
            id="skipper-notification-form"
            class="skipper-notification__form"
            phx-change="validate_notification"
            phx-submit="save_notification"
          >
            <div class="skipper-notification__field">
              <div class="skipper-notification__input-wrap">
                <.icon
                  name="hero-envelope"
                  class="skipper-notification__input-icon size-4"
                />
                <.input
                  field={@notification_form[:notification_email]}
                  id="skipper-notification-email"
                  type="email"
                  class="input validator w-full pl-9"
                  placeholder="your@email.com"
                  autocomplete="email"
                  aria-label="Email address"
                  required
                />
              </div>
              <div class="validator-hint hidden">Enter a valid email address</div>
            </div>

            <.button
              id="skipper-notification-submit"
              type="submit"
              class="btn btn-primary"
            >
              Notify
            </.button>
          </.form>
        </div>

        <form
          method="dialog"
          class="modal-backdrop"
          phx-submit="close_notification_modal"
        >
          <button type="submit" aria-label="Close notification form">Close</button>
        </form>
      </dialog>

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
              open={@open_source_id == task.id}
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
        Harbor.SkipperStream.subscribe(run.id)
      end

      recent_prompts = Prompts.list_prompts(browser_session_id, limit: 10)

      {:ok,
       socket
       |> assign(:page_title, "Show Skipper")
       |> assign(:browser_session_id, browser_session_id)
       |> assign(:owner?, prompt.browser_session_id == browser_session_id)
       |> assign(:notification_form, Prompt.notification_changeset(prompt, %{}) |> to_form())
       |> assign(:notification_form_open?, false)
       |> assign(:open_source_id, nil)
       |> assign(:prompt, prompt)
       |> assign(:recent_prompts, recent_prompts)
       |> assign(:content, prompt.content)
       |> assign(:current_prompt_id, prompt.id)
       |> assign(:run_id, run.id)
       |> assign(:run_finished?, run.status in [:succeeded, :failed])
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

  def handle_event("toggle_source", %{"id" => id}, socket) do
    with {source_id, ""} <- Integer.parse(id),
         true <- Map.has_key?(socket.assigns.response_tasks_by_id, source_id) do
      previous_source_id = socket.assigns.open_source_id
      open_source_id = if previous_source_id == source_id, do: nil, else: source_id

      socket =
        socket
        |> assign(:open_source_id, open_source_id)
        |> refresh_source_cards([previous_source_id, source_id])

      {:noreply, socket}
    else
      _other -> {:noreply, socket}
    end
  end

  def handle_event(
        "open_notification_modal",
        _params,
        %{assigns: %{owner?: true}} = socket
      ) do
    {:noreply, assign(socket, :notification_form_open?, true)}
  end

  def handle_event("open_notification_modal", _params, socket), do: {:noreply, socket}

  def handle_event("close_notification_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:notification_form_open?, false)
     |> assign(
       :notification_form,
       Prompt.notification_changeset(socket.assigns.prompt, %{}) |> to_form()
     )}
  end

  def handle_event(
        "validate_notification",
        %{"prompt" => notification_params},
        %{assigns: %{owner?: true, run_finished?: false}} = socket
      ) do
    changeset =
      socket.assigns.prompt
      |> Prompt.notification_changeset(notification_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :notification_form, to_form(changeset))}
  end

  def handle_event(
        "save_notification",
        %{"prompt" => notification_params},
        %{assigns: %{owner?: true, run_finished?: false}} = socket
      ) do
    case Prompts.set_notification_email(
           socket.assigns.browser_session_id,
           socket.assigns.prompt.id,
           notification_params
         ) do
      {:ok, prompt} ->
        Harbor.PromptNotifier.deliver_run_finished(prompt.gust_run_id)

        {:noreply,
         socket
         |> assign(:prompt, prompt)
         |> assign(:notification_form_open?, false)
         |> assign(:notification_form, Prompt.notification_changeset(prompt, %{}) |> to_form())}

      {:error, changeset} ->
        {:noreply, assign(socket, :notification_form, to_form(changeset))}
    end
  end

  def handle_event(event, _params, socket)
      when event in ["validate_notification", "save_notification"],
      do: {:noreply, socket}

  defp assign_tasks_results(socket, run_id) do
    streamed_responses = Map.get(socket.assigns, :streamed_responses, %{})

    response_tasks =
      run_id
      |> get_responses_task()
      |> Enum.map(&with_streamed_response(&1, streamed_responses))

    analysis_task = Flows.get_task_by_name_run("judge_analysis", run_id)
    synthesize_task = Flows.get_task_by_name_run("synthesize", run_id)
    streamed_synthesis = Map.get(socket.assigns, :streamed_synthesis)

    synthesize_result =
      case task_result(synthesize_task, "answer", nil) do
        content when is_binary(content) and content != "" -> content
        _other -> streamed_synthesis
      end

    socket
    |> assign(
      analysis_result: task_result(analysis_task, "analysis", %{}),
      analysis_task: analysis_task,
      models_used: length(response_tasks),
      response_tasks_by_id: Map.new(response_tasks, &{&1.id, &1}),
      streamed_responses: streamed_responses,
      streamed_synthesis: streamed_synthesis,
      synthesize_result: synthesize_result,
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

  defp with_streamed_response(task, streamed_responses) do
    case task_result(task, "content", nil) do
      content when is_binary(content) and content != "" ->
        task

      _other ->
        case Map.fetch(streamed_responses, task.id) do
          {:ok, content} -> %{task | result: Map.put(task.result, "content", content)}
          :error -> task
        end
    end
  end

  @impl true
  def handle_info(
        {:dag, :run_status, %{run_id: run_id, status: status, task_id: task_id}},
        socket
      ) do
    {:noreply,
     socket
     |> maybe_assign_run_finished(status, task_id)
     |> assign_tasks_results(run_id)}
  end

  def handle_info(
        {:skipper_stream,
         %{run_id: run_id, kind: kind, task_id: task_id, event: event, content: content}},
        %{assigns: %{run_id: run_id}} = socket
      ) do
    socket =
      case {kind, event} do
        {:source, :started} -> put_response_content(socket, task_id, "")
        {:source, :delta} -> append_response_content(socket, task_id, content)
        {:source, :finished} -> put_response_content(socket, task_id, content)
        {:synthesis, :started} -> put_synthesis_content(socket, task_id, "")
        {:synthesis, :delta} -> append_synthesis_content(socket, task_id, content)
        {:synthesis, :finished} -> put_synthesis_content(socket, task_id, content)
      end

    {:noreply, socket}
  end

  defp maybe_assign_run_finished(socket, status, nil) do
    run_finished? = status in [:succeeded, :failed]

    socket
    |> assign(:run_finished?, run_finished?)
    |> assign(:notification_form_open?, !run_finished? && socket.assigns.notification_form_open?)
  end

  defp maybe_assign_run_finished(socket, _status, _task_id), do: socket

  defp append_response_content(socket, task_id, delta) do
    with {:ok, task, socket} <- response_task(socket, task_id),
         false <- task.status == :succeeded do
      content = Map.get(socket.assigns.streamed_responses, task_id, "") <> delta
      put_response_content(socket, task_id, content)
    else
      _other -> socket
    end
  end

  defp put_response_content(socket, task_id, content) do
    case response_task(socket, task_id) do
      {:ok, task, socket} ->
        task = %{task | result: Map.put(task.result, "content", content)}

        socket
        |> assign(
          :streamed_responses,
          Map.put(socket.assigns.streamed_responses, task_id, content)
        )
        |> assign(
          :response_tasks_by_id,
          Map.put(socket.assigns.response_tasks_by_id, task_id, task)
        )
        |> stream_insert(:response_tasks, task, at: task.map_index || -1)

      :error ->
        socket
    end
  end

  defp response_task(socket, task_id) do
    case Map.fetch(socket.assigns.response_tasks_by_id, task_id) do
      {:ok, task} ->
        {:ok, task, socket}

      :error ->
        task = Flows.get_task!(task_id)

        if task.run_id == socket.assigns.run_id and task.name == "get_responses" do
          socket =
            assign(
              socket,
              :response_tasks_by_id,
              Map.put(socket.assigns.response_tasks_by_id, task_id, task)
            )

          {:ok, task, socket}
        else
          :error
        end
    end
  end

  defp append_synthesis_content(socket, task_id, delta) do
    socket = ensure_synthesis_task(socket, task_id)

    case socket.assigns.synthesize_task do
      %{status: :succeeded} ->
        socket

      %{id: ^task_id} ->
        content = (socket.assigns.streamed_synthesis || "") <> delta

        socket
        |> assign(:streamed_synthesis, content)
        |> assign(:synthesize_result, content)

      _other ->
        socket
    end
  end

  defp put_synthesis_content(socket, task_id, content) do
    socket = ensure_synthesis_task(socket, task_id)

    case socket.assigns.synthesize_task do
      %{id: ^task_id} ->
        socket
        |> assign(:streamed_synthesis, content)
        |> assign(:synthesize_result, content)

      _other ->
        socket
    end
  end

  defp ensure_synthesis_task(socket, task_id) do
    case socket.assigns.synthesize_task do
      %{id: ^task_id} ->
        socket

      _other ->
        task = Flows.get_task!(task_id)

        if task.run_id == socket.assigns.run_id and task.name == "synthesize" do
          assign(socket, :synthesize_task, task)
        else
          socket
        end
    end
  end

  defp refresh_source_cards(socket, task_ids) do
    task_ids
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.reduce(socket, fn task_id, socket ->
      case Map.fetch(socket.assigns.response_tasks_by_id, task_id) do
        {:ok, task} ->
          stream_insert(socket, :response_tasks, task, at: task.map_index || -1)

        :error ->
          socket
      end
    end)
  end
end
