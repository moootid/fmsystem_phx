defmodule FmsystemWeb.Router do
  use FmsystemWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", FmsystemWeb do
    pipe_through :api
  end
end
