defmodule TheDotfatherWeb.Router do
  use TheDotfatherWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TheDotfatherWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", TheDotfatherWeb do
    pipe_through :browser

    live "/", MainLive
    live "/tutorial", TutorialLive
    live "/competition", CompetitionLive
  end

  if Application.compile_env(:the_dotfather, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TheDotfatherWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
