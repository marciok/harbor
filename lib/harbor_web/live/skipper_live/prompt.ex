defmodule HarborWeb.SkipperLive.Prompt do
  alias Gust.Flows
  alias GustWeb.Layouts
  alias Harbor.Prompts.Prompt
  alias Harbor.Prompts
  use HarborWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} prompts={@recent_prompts}>
      <section id="skipper" class="skipper-page">
        <.header>
          Skipper
          <:subtitle>
            Send one prompt to multiple models, compare their perspectives, and synthesize the
            strongest ideas.
          </:subtitle>
        </.header>

        <section
          id="skipper-gateway-status"
          role="status"
          class="skipper-gateway-status"
          aria-labelledby="skipper-gateway-status-title"
        >
          <div class="skipper-gateway-status__logo-wrap">
            <img
              src={~p"/images/vercel.svg"}
              alt=""
              aria-hidden="true"
              class="skipper-gateway-status__logo"
            />
          </div>

          <div class="skipper-gateway-status__content">
            <p class="skipper-gateway-status__eyebrow">Model gateway</p>
            <h2 id="skipper-gateway-status-title" class="skipper-gateway-status__title">
              Vercel AI Gateway
            </h2>

            <%= if @models != [] do %>
              <div class="skipper-gateway-status__meta">
                <span class="skipper-gateway-status__balance">
                  Balance
                  <strong
                    id="skipper-current-balance"
                    class="skipper-gateway-status__balance-value"
                  >
                    {@balance_display}
                  </strong>
                </span>
              </div>
            <% else %>
              <p class="skipper-gateway-status__description">
                Load the available models to start a comparison.
              </p>
            <% end %>
          </div>

          <.button
            :if={@models == []}
            id="skipper-load-models"
            type="button"
            class="skipper-gateway-status__action"
            phx-click="load_models"
            disabled={@loading_models}
            aria-busy={@loading_models}
          >
            <.icon name="hero-arrow-path" class="size-4" />
            {if(@loading_models, do: "Loading models…", else: "Load models")}
          </.button>
        </section>

        <.form
          for={@form}
          id="skipper-form"
          class={["skipper-form", @models == [] && "opacity-50"]}
          phx-change="validate"
          phx-submit="send"
        >
          <div id="skipper-form-intro" class="skipper-form__intro">
            <span class="skipper-form__intro-icon">
              <.icon name="hero-arrows-pointing-in" class="size-5" />
            </span>
            <div>
              <h2 class="skipper-form__title">Ask the model panel</h2>
              <p class="skipper-form__description">
                Your selected models respond independently before Skipper analyzes and combines
                their strongest ideas.
              </p>
            </div>
          </div>

          <section
            id="skipper-model-panel"
            class="skipper-model-panel"
            aria-labelledby="skipper-model-panel-heading"
          >
            <header class="skipper-model-panel__header">
              <div>
                <p id="skipper-model-panel-heading" class="skipper-model-panel__eyebrow">
                  Panelists
                </p>
              </div>
              <.model_picker
                id="skipper-add-model"
                models={@models}
                event="add_model"
                label="Add model"
                variant={:add}
                close_on_select={false}
              />
            </header>
            <div id="skipper-model-panel-list" class="skipper-model-panel__grid" phx-update="stream">
              <.panel_model
                :for={{dom_id, panel_model} <- @streams.panel_models}
                id={dom_id}
                model={panel_model}
              />
            </div>

            <div id="skipper-synthesizer" class="skipper-synthesizer">
              <div class="skipper-synthesizer__route" aria-hidden="true">
                <span></span>
                <.icon name="hero-arrow-down" class="size-4" />
              </div>
              <div class="skipper-synthesizer__content">
                <div class="skipper-synthesizer__field">
                  <span class="skipper-synthesizer__label">Synthesizer</span>
                  <.input
                    field={@synthesizer_form[:synthesizer]}
                    id="skipper-synthesizer-model"
                    type="hidden"
                    class="hidden"
                  />
                  <.model_picker
                    id="skipper-synthesizer"
                    models={@models}
                    event="select_synthesizer"
                    label="Select a model"
                    selected_model={@selected_synthesizer}
                  />
                </div>
              </div>
            </div>
          </section>

          <.input
            field={@form[:content]}
            id="skipper-prompt"
            type="textarea"
            rows="7"
            placeholder="Ask a question that benefits from multiple perspectives…"
            autofocus
          />

          <footer class="justify-end">
            <.button
              id="skipper-send"
              variant="primary"
              disabled={@prompt_disabled?}
              type="submit"
            >
              <.icon name="hero-sparkles" class="size-4" /> Run Skipper
            </.button>
          </footer>
        </.form>
        <.zero_balance_modal open={insufficient_balance?(@balance)} />
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, %{"browser_session_id" => browser_session_id}, socket) do
    dag =
      Flows.get_dag_by_name_with_runs!("fetch_models",
        limit: 1,
        offset: 0,
        status: :succeeded
      )

    socket =
      case dag.runs do
        [run] ->
          assign_from_gust_run_id(socket, run.id)

        [] ->
          socket
          |> assign(:prompt_disabled?, true)
          |> assign(:models, [])
          |> stream(:panel_models, [])
          |> assign(:balance_display, nil)
          |> assign(:balance, nil)
          |> assign(:selected_synthesizer, nil)
          |> assign(
            :synthesizer_form,
            to_form(%{"synthesizer" => nil}, as: :skipper_config)
          )
      end

    recent_prompts = Prompts.list_prompts(browser_session_id, limit: 10)

    {:ok,
     socket
     |> assign(:recent_prompts, recent_prompts)
     |> assign(:loading_models, false)
     |> assign(:load_models_run_id, nil)
     |> assign(:browser_session_id, browser_session_id)
     |> assign(:form, Prompt.form_changeset(%Prompt{}, %{}) |> to_form())}
  end

  def handle_event("add_model", %{"id" => id}, socket) do
    model = find_model(socket, id)
    selected_models = [model | socket.assigns.selected_models]

    {:noreply,
     socket
     |> stream_insert(:panel_models, model)
     |> assign(:selected_models, selected_models)}
  end

  @impl true
  def handle_event("load_models", _params, socket) do
    dag = Flows.get_dag_by_name("fetch_models")
    {:ok, run} = Flows.create_run(%{dag_id: dag.id})

    Gust.PubSub.subscribe_run(run.id)
    Gust.DAG.Run.Trigger.dispatch_run(run)

    {:noreply,
     socket
     |> put_flash(:info, "Refreshing models!")
     |> assign(:load_models_run_id, run.id)
     |> assign(:loading_models, true)}
  end

  def handle_event("remove_model", %{"id" => id}, socket) do
    selected_models = socket.assigns.selected_models

    if length(socket.assigns.selected_models) == 1 do
      {:noreply, socket |> put_flash(:error, "You need at least one model")}
    else
      model = find_model(socket, id)
      selected_models = List.delete(selected_models, model)

      {:noreply,
       socket
       |> stream_delete_by_dom_id(:panel_models, "panel_models-#{id}")
       |> assign(:selected_models, selected_models)}
    end
  end

  def handle_event(
        "select_synthesizer",
        %{"id" => synthesizer},
        socket
      ) do
    model = find_model(socket, synthesizer)

    {:noreply,
     socket
     |> assign(:selected_synthesizer, model)
     |> assign(
       :synthesizer_form,
       to_form(%{"synthesizer" => synthesizer}, as: :skipper_config)
     )}
  end

  def handle_event(
        "validate",
        %{"prompt" => prompt_params},
        socket
      ) do
    changeset =
      %Prompt{}
      |> Prompt.form_changeset(prompt_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event(
        "send",
        %{
          "prompt" => prompt_params,
          "skipper_config" => %{"synthesizer" => synthesizer}
        },
        socket
      ) do
    changeset = Prompt.form_changeset(%Prompt{}, prompt_params)

    case Ecto.Changeset.apply_action(changeset, :insert) do
      {:ok, prompt} ->
        dag = Flows.get_dag_by_name("skipper_prompt")
        synthesizer = find_model(socket, synthesizer)

        {:ok, run} =
          Flows.create_run(%{
            dag_id: dag.id,
            params: %{
              prompt: prompt.content,
              synthesizer: synthesizer,
              panel: Enum.map(socket.assigns.selected_models, & &1)
            }
          })

        Gust.DAG.Run.Trigger.dispatch_run(run)

        {:ok, prompt} =
          Harbor.Prompts.create_prompt(socket.assigns.browser_session_id, run.id, prompt_params)

        {:noreply, socket |> push_navigate(to: ~p"/skipper/#{prompt.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp assign_from_gust_run_id(socket, run_id) do
    models_task = Flows.get_task_by_name_run("fetch", run_id)
    budget_task = Flows.get_task_by_name_run("get_budget", run_id)

    balance = Decimal.new(budget_task.result["balance"])
    balance_display = balance |> Decimal.round(2) |> Decimal.to_string(:normal)

    %{"gust_task_items" => models} = models_task.result

    models =
      for model <- models do
        Map.put(model, :id, model["slug"])
      end

    default_panel = Application.get_env(:harbor, :default_panel_models)
    panel_models = Enum.filter(models, fn %{"slug" => slug} -> slug in default_panel end)

    synthesizer = Application.get_env(:harbor, :default_synth_model)
    synthesizer_model = Enum.find(models, fn %{"slug" => slug} -> synthesizer == slug end)

    socket
    |> assign(:models, models)
    |> stream(:panel_models, panel_models)
    |> assign(:prompt_disabled?, insufficient_balance?(balance))
    |> assign(:balance, balance)
    |> assign(:balance_display, "$#{balance_display}")
    |> assign(:selected_models, panel_models)
    |> assign(
      :synthesizer_form,
      to_form(%{"synthesizer" => synthesizer_model["slug"]}, as: :skipper_config)
    )
    |> assign(:selected_synthesizer, synthesizer_model)
  end

  @impl true
  def handle_info(
        {:dag, :run_status, %{run_id: run_id, status: status, task_id: task_id}},
        socket
      ) do
    socket =
      case {status, task_id, socket.assigns.load_models_run_id} do
        {:succeeded, nil, ^run_id} ->
          socket
          |> assign_from_gust_run_id(run_id)
          |> finish_loading_models()

        {:failed, nil, ^run_id} ->
          socket
          |> put_flash(:error, "Unable to load models. Please try again.")
          |> finish_loading_models()

        _other ->
          socket
      end

    {:noreply, socket}
  end

  defp insufficient_balance?(nil), do: false

  defp insufficient_balance?(%Decimal{} = decimal_balance) do
    Decimal.compare(decimal_balance, 1) in [:lt, :eq]
  end

  defp finish_loading_models(socket) do
    assign(socket,
      loading_models: false,
      load_models_run_id: nil
    )
  end

  defp find_model(socket, id) do
    Enum.find(socket.assigns.models, &(&1[:id] == id))
  end
end
