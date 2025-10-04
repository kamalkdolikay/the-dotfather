defmodule TheDotfatherWeb.PageController do
  use TheDotfatherWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
