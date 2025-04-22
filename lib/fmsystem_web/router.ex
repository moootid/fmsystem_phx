defmodule FmsystemWeb.Router do
  use FmsystemWeb, :router
  alias FmsystemWeb.Plugs.VerifyJWT

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    # Verify JWT and load current_user
    plug VerifyJWT
  end

  scope "/api", FmsystemWeb do
    pipe_through :api
    # --- Public Routes ---
    get "/health", GeneralController, :health
    # More descriptive action name
    post "/register", UserController, :register
    # More descriptive action name
    post "/login", SessionController, :login
    post "/telemetry", TelemetryController, :create
    # --- Protected Routes (require authentication) ---
    scope "/" do
      # Add JWT verification pipeline
      pipe_through :api_auth

      # Session / Current User
      # Endpoint to get current user info
      get "/me", SessionController, :show

      # API Auth CRUD
      get "/api_auth", ApiAuthController, :index
      post "/api_auth", ApiAuthController, :create
      get "/api_auth/:id", ApiAuthController, :show
      patch "/api_auth/:id", ApiAuthController, :update
      put "/api_auth/:id", ApiAuthController, :update
      delete "/api_auth/:id", ApiAuthController, :delete

      # Vehicle CRUD
      get "/vehicles", VehicleController, :index
      post "/vehicles", VehicleController, :create
      get "/vehicles/:id", VehicleController, :show
      patch "/vehicles/:id", VehicleController, :update
      put "/vehicles/:id", VehicleController, :update
      delete "/vehicles/:id", VehicleController, :delete

      # IoT CRUD
      get "/iot", IotController, :index
      post "/iot", IotController, :create
      get "/iot/:id", IotController, :show
      patch "/iot/:id", IotController, :update
      put "/iot/:id", IotController, :update
      delete "/iot/:id", IotController, :delete
    end
  end
end
