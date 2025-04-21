defmodule FmsystemWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :fmsystem

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_fmsystem_key",
    signing_salt: "omiuLVqy",
    same_site: "Lax"
  ]

  # socket "/live", Phoenix.LiveView.Socket,
  #   websocket: [connect_info: [session: @session_options]],
  #   longpoll: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :fmsystem,
    gzip: false,
    only: FmsystemWeb.static_paths()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :fmsystem
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  # --- CORS Configuration ---
  # IMPORTANT: Restrict origin in production!
  plug CORSPlug,
    # Use System.get_env("CORS_ORIGIN") or a list in prod
    origin: "*",
    methods: ~w(GET POST PUT PATCH DELETE OPTIONS),
    # Add any other headers clients send
    headers: ~w(Authorization Content-Type X-Requested-With),
    # 1 day
    max_age: 86_400,
    credentials: true

  # --- Session Configuration ---
  # Needed for flash messages, CSRF protection (if used), etc. Can be minimal for API.
  plug Plug.Session,
    store: :cookie,
    key: "_fmsystem_key",
    # Use `mix phx.gen.secret 32`
    signing_salt: "CHANGE_ME_SIGNING",
    # Use `mix phx.gen.secret 32`
    encryption_salt: "CHANGE_ME_ENCRYPTION"

  # --- Router ---
  # Comes *after* CORS, Parsers, Session
  plug FmsystemWeb.Router
end
