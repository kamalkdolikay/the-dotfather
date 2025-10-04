defmodule TheDotfatherWeb.CompetitionLive do
  use TheDotfatherWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Competition")
     |> assign(:status, :idle)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="competition-shell" class="min-h-screen bg-slate-950 text-slate-100" phx-hook="MorseInput">
      <div id="competition-live" phx-hook="Competition" class="h-full">
        <header class="px-6 py-8 text-center">
          <h1 class="text-3xl font-semibold tracking-tight">Competition Arena</h1>
          <p class="mt-2 text-slate-300">
            Press Dash to start matching. Long-Dash exits to the main page.
          </p>
        </header>

        <section class="mx-auto flex max-w-5xl flex-col gap-6 px-6 pb-20">
          <div class="grid gap-6 md:grid-cols-[1.4fr_1fr]">
            <div class="space-y-4 rounded-3xl border border-slate-800/80 bg-slate-900/70 p-6 shadow-xl shadow-slate-900/60">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm uppercase tracking-widest text-slate-400">Highest Score</p>
                  <p id="highest-score" class="text-3xl font-semibold text-emerald-300">0</p>
                </div>
                <button
                  id="matchmaking-status"
                  class="rounded-full bg-emerald-500/20 px-4 py-1 text-sm font-medium text-emerald-200"
                >
                  Idle
                </button>
              </div>

              <div class="rounded-2xl border border-slate-800/60 bg-slate-950/80 p-4">
                <p class="text-sm text-slate-300" id="queue-prompt">Press Dash to start matching</p>
              </div>

              <div class="space-y-4 rounded-2xl border border-slate-800/60 bg-slate-950/80 p-6">
                <div class="flex items-center justify-between">
                  <p class="text-sm uppercase tracking-widest text-slate-400">Question</p>
                  <p class="text-sm text-slate-500" id="question-counter">-</p>
                </div>
                <h2 id="question-prompt" class="text-3xl font-semibold text-emerald-200">
                  Waiting for opponent...
                </h2>
                <p id="question-type" class="text-sm uppercase tracking-widest text-slate-500">
                  &nbsp;
                </p>
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-sm text-slate-400">Your Input</p>
                    <div
                      id="player-input"
                      class="mt-2 flex min-h-[3rem] min-w-[12rem] flex-wrap items-center gap-2 rounded-2xl border border-slate-800/60 bg-slate-950 px-4 py-2 font-mono text-xl text-emerald-300"
                    >
                    </div>
                  </div>
                  <div class="text-right">
                    <p class="text-sm text-slate-400">Time Remaining</p>
                    <p id="question-timer" class="text-3xl font-semibold text-rose-300">-</p>
                  </div>
                </div>
                <p id="answer-feedback" class="text-sm text-slate-400"></p>
              </div>
            </div>

            <aside class="space-y-6 rounded-3xl border border-slate-800/80 bg-slate-900/70 p-6 shadow-xl shadow-slate-900/60">
              <div>
                <p class="text-sm uppercase tracking-widest text-slate-400">Scores</p>
                <div id="scoreboard" class="mt-3 space-y-3">
                  <div class="rounded-2xl border border-slate-800/60 bg-slate-950/80 px-4 py-3 text-slate-500">
                    Waiting for players...
                  </div>
                </div>
              </div>

              <div class="space-y-2 rounded-2xl border border-slate-800/60 bg-slate-950/80 p-4 text-sm text-slate-300">
                <p class="font-semibold text-slate-200">Controls</p>
                <ul class="space-y-1 text-slate-400">
                  <li>Dot: add a dot to your answer</li>
                  <li>Dash: add a dash / confirm prompts</li>
                  <li>Long-Dash: exit to main page</li>
                </ul>
              </div>

              <div
                class="rounded-2xl border border-slate-800/60 bg-slate-950/80 p-4 text-sm text-slate-400"
                id="match-summary"
              >
              </div>
            </aside>
          </div>
        </section>
      </div>
    </div>
    """
  end
end
