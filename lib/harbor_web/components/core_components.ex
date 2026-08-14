defmodule HarborWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: HarborWeb.Gettext

  alias HarborWeb.ModelProvider
  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :string
  attr :variant, :string, values: ~w(primary)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{"primary" => "btn-primary", nil => "btn-primary btn-soft"}

    assigns =
      assign_new(assigns, :class, fn ->
        ["btn", Map.fetch!(variants, assigns[:variant])]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
               search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :string, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :string, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="fieldset mb-2">
      <label>
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <span class="label">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={@class || "checkbox checkbox-sm"}
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[@class || "w-full select", @errors != [] && (@error_class || "select-error")]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || "w-full textarea bg-white",
            @errors != [] && (@error_class || "textarea-error")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || "w-full input",
            @errors != [] && (@error_class || "input-error")
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error">
      <.icon name="hero-exclamation-circle" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm leading-6 text-slate-600">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="table table-zebra">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          <th :if={@action != []}>
            <span class="sr-only">{gettext("Actions")}</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li :for={item <- @item} class="list-row">
        <div class="list-col-grow">
          <div class="font-bold">{item.title}</div>
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  @doc false
  attr :id, :string, required: true
  attr :models, :list, required: true
  attr :event, :string, required: true
  attr :label, :string, required: true
  attr :selected_model, :map, default: nil
  attr :variant, :atom, values: [:add, :select], default: :select
  attr :close_on_select, :boolean, default: true

  def model_picker(assigns) do
    ~H"""
    <details id={"#{@id}-menu"} class={["model-picker", "model-picker--#{@variant}"]}>
      <summary id={"#{@id}-button"} class="model-picker__trigger">
        <%= if @variant == :add do %>
          <.icon name="hero-plus" class="size-4" />
          <span>{@label}</span>
        <% else %>
          <span :if={@selected_model} class="model-picker__selected-logo">
            <img
              src={ModelProvider.icon_path(@selected_model["owner"])}
              alt=""
              class="model-picker__logo-image"
            />
          </span>
          <span class="model-picker__selection">
            <span class="model-picker__name">
              {if(@selected_model, do: @selected_model["name"], else: @label)}
            </span>
            <span :if={@selected_model} class="model-picker__provider">
              {ModelProvider.name(@selected_model["owner"])}
            </span>
          </span>
        <% end %>
        <.icon name="hero-chevron-down" class="model-picker__chevron size-4" />
      </summary>
      <div class="model-picker__options">
        <button
          :for={model <- @models}
          type="button"
          id={"#{@id}-option-#{model[:id]}"}
          class={[
            "model-picker__option",
            @selected_model == model && "model-picker__option--selected"
          ]}
          aria-pressed={if(@variant == :select, do: @selected_model == model, else: nil)}
          phx-click={model_picker_click(@event, model[:id], @close_on_select, @id)}
        >
          <span class="model-picker__option-logo">
            <img
              src={ModelProvider.icon_path(model["owner"])}
              alt=""
              class="model-picker__logo-image"
            />
          </span>
          <span class="min-w-0 flex-1">
            <span class="model-picker__name">{model["name"]}</span>
            <span class="model-picker__provider">
              {ModelProvider.name(model["owner"])}
            </span>
          </span>
          <.icon
            :if={@variant == :add}
            name="hero-plus"
            class="size-4 shrink-0 text-sky-600"
          />
          <.icon
            :if={@variant == :select && @selected_model == model}
            name="hero-check"
            class="size-4 shrink-0 text-sky-600"
          />
        </button>
      </div>
    </details>
    """
  end

  defp model_picker_click(event, model_id, close_on_select, id) do
    click = JS.push(event, value: %{id: model_id})

    if close_on_select do
      JS.remove_attribute(click, "open", to: "##{id}-menu")
    else
      click
    end
  end

  @doc false
  attr :id, :string, required: true
  attr :model, :map, required: true
  attr :removable, :boolean, default: true
  attr :selected, :boolean, default: false

  def panel_model(assigns) do
    ~H"""
    <article
      id={@id}
      class={["skipper-panel-model", @selected && "skipper-panel-model--selected"]}
    >
      <span class="skipper-panel-model__logo">
        <img
          src={ModelProvider.icon_path(@model["owner"])}
          alt=""
          class="skipper-panel-model__image"
        />
      </span>
      <span class="min-w-0 flex-1">
        <span class="skipper-panel-model__name">{@model["name"]}</span>
        <span class="skipper-panel-model__provider">
          {ModelProvider.name(@model["owner"])}
        </span>
      </span>
      <button
        :if={@removable}
        type="button"
        id={"#{@id}-remove"}
        class="skipper-panel-model__remove"
        phx-click="remove_model"
        phx-value-id={@model[:id]}
      >
        <.icon name="hero-x-mark" class="size-4" />
      </button>
    </article>
    """
  end

  @doc false
  attr :id, :string, required: true
  attr :task, :map, default: nil

  def task_status(assigns) do
    ~H"""
    <GustWeb.DagRunComponents.status_badge
      :if={@task}
      id={@id}
      status={@task.status}
      data-status={@task.status}
    />
    <span
      :if={@task && @task.status == :running}
      class="loading loading-spinner text-primary"
    >
    </span>
    """
  end

  @doc false
  attr :id, :string, required: true
  attr :icon, :string, required: true

  def stage_empty(assigns) do
    ~H"""
    <div id={@id} class={["skipper-empty-state", "hidden", "only:flex"]}>
      <span class="skipper-empty-state__icon">
        <.icon name={@icon} class="size-5" />
      </span>
    </div>
    """
  end

  @doc false
  attr :id, :string, required: true
  attr :source, :map, required: true

  def source_card(assigns) do
    assigns =
      assign_new(assigns, :content, fn ->
        if assigns[:source].error != %{} do
          """
          ## Ops! Response failed  
            #{assigns[:source].error["message"]}
          """
        else
          result = assigns[:source].result

          if result do
            result["content"] || "*Response received. Preparing it for display…*"
          else
            "*Waiting for the model to respond…*"
          end
        end
      end)

    ~H"""
    <details id={@id} class="skipper-disclosure">
      <summary class="skipper-disclosure__summary">
        <span class="skipper-model-badge">
          <img
            src={ModelProvider.icon_path(@source.params["owner"])}
            alt=""
            class="skipper-model-badge__image"
          />
        </span>

        <span class="min-w-0 flex-1">
          <span class="skipper-disclosure__title">{@source.params["name"]}</span>
          <span class="skipper-disclosure__meta">
            {ModelProvider.name(@source.params["owner"])}
          </span>
        </span>

        <.task_status id={"#{@id}-status"} task={@source} />

        <.icon name="hero-chevron-down" class="skipper-disclosure__chevron size-5" />
      </summary>
      <div class="skipper-disclosure__content">
        <.markdown content={@content} id={"#{@id}-content"} />
      </div>
    </details>
    """
  end

  attr :id, :string, required: true
  attr :content, :string, required: true

  def markdown(assigns) do
    html =
      MDEx.to_html!(
        assigns.content,
        extension: [
          autolink: true,
          footnotes: true,
          strikethrough: true,
          table: true,
          tasklist: true
        ],
        parse: [
          relaxed_autolinks: true,
          relaxed_tasklist_matching: true
        ],
        render: [unsafe: true],
        sanitize: MDEx.Document.default_sanitize_options()
      )

    assigns = assign(assigns, :html, Phoenix.HTML.raw(html))

    ~H"""
    <div id={@id} class={["markdown break-words"]}>
      {@html}
    </div>
    """
  end

  @doc false
  attr :title, :string, required: true
  attr :items, :list, required: true

  def analysis_card(assigns) do
    assigns =
      assign_new(assigns, :item_list, fn ->
        case assigns[:items] do
          items when is_list(items) ->
            items

          items when is_binary(items) ->
            [items]
        end
      end)
      |> assign_new(:icon_name, fn ->
        icons = %{
          "blind_spots" => "hero-eye-slash",
          "consensus" => "hero-check-badge",
          "contradictions" => "hero-arrows-right-left",
          "partial_coverage" => "hero-adjustments-horizontal",
          "unique_insights" => "hero-light-bulb"
        }

        icons[assigns[:title]]
      end)

    ~H"""
    <details id={"analysis-#{@title}"} class="skipper-disclosure skipper-analysis-card">
      <summary class="skipper-disclosure__summary">
        <span class="skipper-analysis-card__icon">
          <.icon name={@icon_name} class="size-5" />
        </span>
        <span class="skipper-disclosure__title flex-1">
          {String.capitalize(@title) |> String.replace("_", " ")}
        </span>
        <span class="skipper-stage__count">
          {length(@item_list)} point(s)
        </span>
        <.icon name="hero-chevron-down" class="skipper-disclosure__chevron size-5" />
      </summary>
      <div class="skipper-disclosure__content">
        <ul class="skipper-analysis-list">
          <li :for={item <- @item_list} class="skipper-analysis-list__item">
            <.icon name="hero-arrow-right" class="mt-0.5 size-4 shrink-0" />
            {item}
          </li>
        </ul>
      </div>
    </details>
    """
  end

  @doc false
  attr :open, :boolean, required: true

  def zero_balance_modal(assigns) do
    ~H"""
    <dialog
      id="zero-balance-modal"
      class={["modal"]}
      open={@open}
      aria-labelledby="zero-balance-modal-title"
      aria-describedby="zero-balance-modal-description"
    >
      <div class={["modal-box zero-balance-modal__panel"]}>
        <form method="dialog">
          <button
            id="zero-balance-modal-close"
            type="submit"
            class={["zero-balance-modal__close"]}
            aria-label="Close message"
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </form>

        <header class={["zero-balance-modal__header"]}>
          <div class={["zero-balance-modal__avatar"]}>
            <img
              id="zero-balance-modal-avatar"
              src="/images/marcio.jpg"
              alt="Marcio, the developer of Harbor"
              width="80"
              height="80"
              class={["zero-balance-modal__avatar-image"]}
            />
          </div>
          <div>
            <h3 id="zero-balance-modal-title" class={["zero-balance-modal__title"]}>
              This demo is out of credits for now :(
            </h3>
          </div>
        </header>

        <div class={["zero-balance-modal__body"]}>
          <p>
            Hi, I'm <a href="http://x.com/marciok" target="_blank">@Marcio</a>.
          </p>

          <p id="zero-balance-modal-description" class={["zero-balance-modal__copy"]}>
            I built Harbor and personally cover the AI usage for this demo.
            This month’s shared balance has been used up, so new runs are paused.
          </p>

          <div id="zero-balance-local-option" class={["zero-balance-modal__option"]}>
            <div>
              <p class={["zero-balance-modal__option-copy"]}>
                The good news is that you can <a href="">run Harbor locally</a>
                with your own model-provider keys!
              </p>
            </div>
          </div>

          <p class={["zero-balance-modal__copy"]}>
            If you prefer the hosted experience
          </p>

          <div class={["zero-balance-modal__actions"]}>
            <a
              id="zero-balance-github-link"
              href="https://forms.fillout.com/t/9jqCJaRhnsus"
              target="_blank"
              rel="noopener noreferrer"
              class={["zero-balance-modal__primary-action"]}
            >
              Click here and let me know
              <.icon name="hero-arrow-top-right-on-square" class="size-4" />
            </a>
          </div>

          <p class={["zero-balance-modal__footnote"]}>
            Credits are reset monthly.
          </p>
        </div>
      </div>

      <form method="dialog" class={["modal-backdrop"]}>
        <button type="submit" aria-label="Close message">Close</button>
      </form>
    </dialog>
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(HarborWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(HarborWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
