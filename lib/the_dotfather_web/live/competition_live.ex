defmodule TheDotfatherWeb.CompetitionLive do
  use TheDotfatherWeb, :live_view

  alias TheDotfatherWeb.CompetitionLiveHTML

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Competition")
     |> assign(:status, :idle)}
  end

  @impl true
  def handle_event("morse_input", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns), do: CompetitionLiveHTML.competition(assigns)
end
