defmodule TheDotfatherWeb.MainLive do
  use TheDotfatherWeb, :live_view

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
  def render(assigns) do
    ~H"""
    <div
      id="main-root"
      \r\n
      class="min-h-screen bg-slate-950 text-slate-100 flex flex-col items-center justify-center gap-12"
      phx-hook="MorseInput"
    >
      <div class="text-center space-y-6">
        <img src="/images/dot-dash.svg" alt="Dot and dash illustration" class="mx-auto w-40 h-40" />
        <h1 class="text-4xl font-semibold tracking-tight">The Dotfather</h1>
        <p class="text-lg text-slate-300">Press Dot for the Tutorial or Dash for Competition.</p>
      </div>
      <div class="rounded-3xl border border-slate-800/70 bg-slate-900/70 px-6 py-4 shadow-xl shadow-slate-900/70">
        <p class="text-base font-medium tracking-wide uppercase text-emerald-300">{assigns.prompt}</p>
        <p class="mt-2 text-sm text-slate-400">Long press (&gt;3s) exits any screen.</p>
      </div>
    </div>
    """
  end
end
