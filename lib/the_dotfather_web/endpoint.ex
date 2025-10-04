defmodule TheDotfatherWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :the_dotfather

  @session_options [
    store: :cookie,
    key: "_the_dotfather_key",
    signing_salt: "AkwzL5Tv",
    same_site: "Lax"
  ]

  socket "/socket", TheDotfatherWeb.UserSocket,
    websocket: [connect_info: [:peer_data, :x_headers, :user_agent]],
    longpoll: false

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :the_dotfather,
    gzip: not code_reloading?,
    only: TheDotfatherWeb.static_paths()

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :the_dotfather
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug TheDotfatherWeb.Router
end
