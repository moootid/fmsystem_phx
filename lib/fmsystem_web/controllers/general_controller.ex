defmodule FmsystemWeb.GeneralController do
  use FmsystemWeb, :controller

  def health(conn, _params) do
    text(conn, "OK")
  end
end
