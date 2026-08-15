defmodule HarborWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use HarborWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :prompts, :list, default: [], doc: "recent browser-owned prompts"
  attr :current_prompt_id, :string, default: nil, doc: "the current prompt identifier"
  attr :show_sidebar, :boolean, default: true, doc: "whether to render the app sidebar"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div id="app-shell" class="app-shell">
      <div class="app-shell__body">
        <header :if={@show_sidebar} id="mobile-app-bar" class="mobile-app-bar">
          <.link navigate={~p"/"} class="mobile-app-bar__brand">
            <img
              src={~p"/images/logo.svg"}
              alt="Gust"
              class="mobile-app-bar__logo"
            />
            <span class="gust-wordmark">Harbor</span>
          </.link>
          <button
            type="button"
            id="mobile-navigation-button"
            class="mobile-app-bar__menu-button"
            aria-label="Open navigation"
            aria-controls="app-sidebar"
            aria-expanded="false"
            phx-click={mobile_navigation(:open)}
          >
            <.icon name="hero-bars-3" class="size-5" />
          </button>
        </header>

        <button
          :if={@show_sidebar}
          type="button"
          id="mobile-navigation-backdrop"
          class="sidebar-backdrop"
          aria-label="Close navigation"
          tabindex="-1"
          phx-click={mobile_navigation(:closed)}
        >
        </button>

        <aside
          :if={@show_sidebar}
          id="app-sidebar"
          class="sidebar"
          aria-label="Application navigation"
          phx-window-keydown={mobile_navigation(:closed)}
          phx-key="escape"
        >
          <div id="app-brand" class="sidebar__brand">
            <.link
              navigate={~p"/"}
              class="sidebar__brand-link"
              phx-click={mobile_navigation(:closed)}
            >
              <img
                src={~p"/images/logo.svg"}
                alt="Gust"
                class="sidebar__logo"
              />
              <span class="gust-wordmark">Harbor</span>
            </.link>
            <button
              type="button"
              id="mobile-navigation-close"
              class="sidebar__close"
              aria-label="Close navigation"
              phx-click={mobile_navigation(:closed)}
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
          </div>

          <nav id="primary-navigation" class="sidebar__links" aria-label="Primary navigation">
            <.link
              navigate={~p"/skipper"}
              class="sidebar__link"
              phx-click={mobile_navigation(:closed)}
            >
              <.icon name="hero-arrows-pointing-in" class="sidebar__icon" />
              <span>Skipper</span>
            </.link>
          </nav>

          <section
            id="sidebar-sessions"
            class="sidebar__sessions"
            aria-labelledby="sidebar-sessions-heading"
          >
            <div class="sidebar__sessions-header">
              <span id="sidebar-sessions-heading">Recent prompts</span>
              <.link
                navigate={~p"/prompts"}
                class="sidebar__sessions-all"
                phx-click={mobile_navigation(:closed)}
              >
                View all
              </.link>
            </div>
            <div id="sidebar-session-list" class="sidebar__session-list">
              <p :if={@prompts == []} id="sidebar-sessions-empty" class="sidebar__sessions-empty">
                No prompts yet
              </p>
              <.link
                :for={prompt <- @prompts}
                id={"sidebar-session-#{prompt.id}"}
                navigate={~p"/skipper/#{prompt.id}"}
                title={prompt.content}
                phx-click={mobile_navigation(:closed)}
                class={[
                  "sidebar__session-link",
                  @current_prompt_id == prompt.id && "sidebar__session-link--active"
                ]}
              >
                <.icon name="hero-chat-bubble-left" class="size-4 shrink-0" />
                <span class="truncate">{prompt.content}</span>
              </.link>
            </div>
          </section>
        </aside>

        <main id="main-content" class="app-main">
          <div class="app-content">
            {render_slot(@inner_block)}
          </div>
        </main>
      </div>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  defp mobile_navigation(state) when state in [:open, :closed] do
    {expanded, focus_target} =
      if state == :open do
        {"true", "#mobile-navigation-close"}
      else
        {"false", "#mobile-navigation-button"}
      end

    js =
      if state == :open do
        JS.add_class(%JS{}, "app-shell--mobile-navigation-open", to: "#app-shell")
      else
        JS.remove_class(%JS{}, "app-shell--mobile-navigation-open", to: "#app-shell")
      end

    js
    |> JS.set_attribute({"aria-expanded", expanded}, to: "#mobile-navigation-button")
    |> JS.focus(to: focus_target)
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
