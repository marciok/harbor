defmodule HarborWeb.Router do
  import GustWeb.DashboardRouter
  use HarborWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HarborWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :browser_session do
    plug HarborWeb.Plugs.EnsureBrowserSession
  end

  auth_enabled? = Application.compile_env(:harbor, :basic_auth)

  if auth_enabled? do
    defp basic_auth(conn, _opts) do
      Plug.BasicAuth.basic_auth(conn,
        username: System.get_env("BASIC_AUTH_USER"),
        password: System.get_env("BASIC_AUTH_PASS")
      )
    end
  end

  scope "/" do
    forward "/images/gust", Plug.Static,
      at: "/",
      from: {:gust_web, "priv/static/images"}
  end

  scope "/", HarborWeb do
    pipe_through [:browser, :browser_session]

    get "/", PageController, :home
    live "/skipper", SkipperLive.Prompt, :new
    live "/skipper/:prompt_id", SkipperLive.Show, :show
    live "/prompts", PromptLive.Index, :index
  end

  scope "/" do
    pipe_through(if auth_enabled?, do: [:browser, :basic_auth], else: :browser)

    gust_dashboard()
  end

  # Other scopes may use custom stacks.
  # scope "/api", HarborWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:harbor, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HarborWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
