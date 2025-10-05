defmodule TheDotfatherWeb.MainLive do
  use TheDotfatherWeb, :live_view

  alias TheDotfatherWeb.MainLiveHTML

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:prompt, "Press anywhere to start - Dot or Dash")}
  end

  @impl true
  def handle_event("morse_input", %{"symbol" => "dot"}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/tutorial")}
  end

  def handle_event("morse_input", %{"symbol" => "dash"}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/competition")}
  end

  def handle_event("morse_input", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns), do: MainLiveHTML.main(assigns)
end
