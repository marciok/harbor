defmodule HarborWeb.PromptLive.Index do
  use HarborWeb, :live_view

  alias Harbor.Prompts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} prompts={@recent_prompts}>
      <.header>
        Prompts
        <:subtitle>All your prompts in this browser.</:subtitle>
      </.header>

      <div id="prompts-runs" class="prompt-index" phx-update="stream">
        <p
          id="prompts-empty"
          class="prompt-index__empty hidden only:flex"
        >
          No prompts yet
        </p>

        <.link
          :for={{dom_id, prompt} <- @streams.all_prompts}
          id={dom_id}
          navigate={~p"/skipper/#{prompt.id}"}
          class="prompt-index__link"
        >
          <span class="prompt-index__icon">
            <.icon name="hero-chat-bubble-bottom-center-text" class="size-5" />
          </span>
          <span class="prompt-index__content">{prompt.content}</span>
          <.icon name="hero-chevron-right" class="prompt-index__chevron" />
        </.link>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, %{"browser_session_id" => browser_session_id}, socket) do
    all_prompts = Prompts.list_prompts(browser_session_id)
    recent_prompts = Enum.take(all_prompts, 10)

    {:ok,
     socket
     |> assign(:page_title, "Prompts")
     |> assign(:recent_prompts, recent_prompts)
     |> stream(:all_prompts, all_prompts)}
  end
end
