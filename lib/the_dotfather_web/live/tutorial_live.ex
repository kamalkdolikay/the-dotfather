defmodule TheDotfatherWeb.TutorialLive do
  use TheDotfatherWeb, :live_view

  alias TheDotfather.{Morse, Tutorial}

  @practice_timeout 4_000

  @impl true
  def mount(_params, _session, socket) do
    lessons = Tutorial.lessons()

    {:ok,
     socket
     |> assign(:lessons, lessons)
     |> assign(:stage, {:intro, :dot})
     |> assign(:input, [])
     |> assign(:prompt, "Quick press to enter Dot")
     |> assign(:info, nil)
     |> assign(:error, nil)
     |> assign(:show_hint, false)
     |> assign(:practice_timer_ref, nil)
     |> assign(:final_message, nil)}
  end

  @impl true
  def handle_event("morse_input", %{"symbol" => symbol}, socket) do
    {:noreply, handle_symbol(socket, String.to_atom(symbol))}
  end

  def handle_event("morse_input", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info(:advance_from_intro, socket) do
    {:noreply,
     socket
     |> assign(:info, nil)
     |> assign(:prompt, lesson_prompt(socket.assigns.lessons, 0, :learning))
     |> assign(:stage, {:lesson, 0, :learning})
     |> assign(:input, [])
     |> assign(:show_hint, false)}
  end

  def handle_info(
        {:practice_timeout, index},
        %{assigns: %{stage: {:lesson, stage_index, :practice}}} = socket
      )
      when index == stage_index do
    {:noreply,
     socket
     |> assign(:show_hint, true)
     |> assign(:prompt, "Look at the image and try again")
     |> assign(:practice_timer_ref, schedule_practice_timeout(index))}
  end

  def handle_info({:practice_timeout, _index}, socket), do: {:noreply, socket}

  ## Rendering -----------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div id="tutorial-root" class="min-h-screen bg-slate-950 text-slate-100" phx-hook="MorseInput">
      <header class="px-6 py-8 text-center">
        <h1 class="text-3xl font-semibold tracking-tight">Tutorial</h1>

        <p class="mt-2 text-slate-300">Learn Morse code through guided practice.</p>
      </header>

      <section class="mx-auto flex max-w-3xl flex-col items-center gap-10 px-6 pb-16">
        <%= if intro_stage?(@stage) do %>
          <.intro_panel stage={@stage} prompt={@prompt} error={@error} input={@input} />
        <% else %>
          <.lesson_panel
            stage={@stage}
            lessons={@lessons}
            prompt={@prompt}
            info={@info}
            error={@error}
            input={@input}
            show_hint={@show_hint}
            final_message={@final_message}
          />
        <% end %>
      </section>
    </div>
    """
  end

  attr :stage, :any
  attr :prompt, :string
  attr :error, :any
  attr :input, :list

  defp intro_panel(assigns) do
    assigns = assign(assigns, :image, intro_image(assigns.stage))

    ~H"""
    <div class="w-full max-w-xl space-y-6">
      <div class="flex flex-col items-center gap-6 rounded-3xl border border-slate-800/80 bg-slate-900/70 p-8 shadow-xl shadow-slate-900/60">
        <img src={@image} alt="Tutorial step" class="h-28 w-28" />
        <p class={flash_class(@error)}>{@prompt}</p>
        <.input_display symbols={@input} />
      </div>
    </div>
    """
  end

  attr :stage, :any
  attr :lessons, :list
  attr :prompt, :string
  attr :info, :any
  attr :error, :any
  attr :input, :list
  attr :show_hint, :boolean, default: false
  attr :final_message, :any

  defp lesson_panel(assigns) do
    assigns = assign(assigns, lesson: current_lesson(assigns.lessons, assigns.stage))

    ~H"""
    <div class="w-full space-y-8">
      <div class="grid gap-6 rounded-3xl border border-slate-800/80 bg-slate-900/70 p-8 shadow-xl shadow-slate-900/60 md:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
        <div class="space-y-4">
          <h2 class="text-4xl font-semibold tracking-tight text-emerald-300">{@lesson.letter}</h2>

          <%= if lesson_learning?(@stage) do %>
            <p class="font-mono text-xl text-emerald-200">
              {Morse.pattern_to_string([@lesson.pattern])}
            </p>
          <% end %>

          <div class="mt-6 flex items-center justify-center">
            <%= if lesson_learning?(@stage) or @show_hint do %>
              <img
                src={@lesson.image}
                alt={"Morse hint for #{@lesson.letter}"}
                class="h-40 w-40 rounded-3xl border border-emerald-400/30 bg-slate-950 object-contain p-4"
              />
            <% else %>
              <div class="h-40 w-40 rounded-3xl border border-slate-800/70 bg-slate-950" />
            <% end %>
          </div>
        </div>

        <div class="flex flex-col justify-center gap-6">
          <p class={flash_class(@error)}>{@prompt}</p>

          <%= if @info do %>
            <p class="text-sm text-slate-400">{@info}</p>
          <% end %>
          <.input_display symbols={@input} />
        </div>
      </div>

      <%= if @final_message do %>
        <div class="rounded-3xl border border-emerald-400/40 bg-emerald-500/10 px-6 py-4 text-center text-emerald-200">
          {@final_message}
        </div>
      <% end %>
    </div>
    """
  end

  attr :symbols, :list

  defp input_display(assigns) do
    ~H"""
    <div class="flex min-h-[3rem] w-full min-w-[16rem] flex-wrap items-center justify-center gap-2 rounded-2xl border border-slate-800/70 bg-slate-900/90 px-4 py-3 font-mono text-xl">
      <%= for symbol <- assigns.symbols do %>
        <span class={symbol_class(symbol)}>{symbol_glyph(symbol)}</span>
      <% end %>

      <%= if assigns.symbols == [] do %>
        <span class="text-slate-600">Waiting for input...</span>
      <% end %>
    </div>
    """
  end

  defp symbol_glyph(:dot), do: "?"
  defp symbol_glyph(:dash), do: "-"

  defp symbol_class(:dot), do: "text-emerald-300"
  defp symbol_class(:dash), do: "text-cyan-300"

  defp flash_class(nil), do: "text-lg text-slate-200"
  defp flash_class(:error), do: "text-lg font-semibold text-rose-300 animate-pulse"

  ## Stage handling -------------------------------------------------------------

  defp handle_symbol(socket, :long_dash) do
    case socket.assigns.stage do
      {:lesson, _index, stage} when stage in [:practice, :navigation] ->
        push_navigate(socket, to: ~p"/")

      {:lesson, _index, :learning} ->
        push_navigate(socket, to: ~p"/")

      {:intro, _} ->
        socket

      _ ->
        socket
    end
  end

  defp handle_symbol(socket, symbol) when symbol in [:dot, :dash] do
    case socket.assigns.stage do
      {:intro, :dot} -> handle_intro_dot(socket, symbol)
      {:intro, :dash} -> handle_intro_dash(socket, symbol)
      {:lesson, index, :learning} -> handle_learning(socket, index, symbol)
      {:lesson, index, :practice} -> handle_practice(socket, index, symbol)
      {:lesson, index, :navigation} -> handle_navigation(socket, index, symbol)
      _ -> socket
    end
  end

  defp handle_intro_dot(socket, :dot) do
    socket
    |> assign(:stage, {:intro, :dash})
    |> assign(:input, [])
    |> assign(:prompt, "Long press to enter Dash")
    |> assign(:error, nil)
  end

  defp handle_intro_dot(socket, _symbol) do
    flash_error(socket, "Quick press to enter Dot")
  end

  defp handle_intro_dash(socket, :dash) do
    socket
    |> assign(:input, [])
    |> assign(:prompt, "Long press over 3 seconds exits or goes back")
    |> assign(:info, "Great! Preparing your first lesson...")
    |> assign(:error, nil)
    |> schedule_intro_advance()
  end

  defp handle_intro_dash(socket, _symbol) do
    flash_error(socket, "Long press to enter Dash")
  end

  defp handle_learning(socket, index, symbol) do
    lesson = current_lesson(socket.assigns.lessons, {:lesson, index, :learning})
    new_input = socket.assigns.input ++ [symbol]

    cond do
      matches_prefix?(lesson.pattern, new_input) and length(new_input) == length(lesson.pattern) ->
        socket
        |> assign(:stage, {:lesson, index, :practice})
        |> assign(:input, [])
        |> assign(:prompt, practice_prompt(lesson.letter))
        |> assign(:error, nil)
        |> assign(:show_hint, false)
        |> restart_practice_timer(index)

      matches_prefix?(lesson.pattern, new_input) ->
        socket
        |> assign(:input, new_input)
        |> assign(:error, nil)

      true ->
        flash_error(socket, "Sorry, try again")
        |> assign(:input, [])
    end
  end

  defp handle_practice(socket, index, symbol) do
    lesson = current_lesson(socket.assigns.lessons, {:lesson, index, :practice})
    new_input = socket.assigns.input ++ [symbol]

    cond do
      matches_prefix?(lesson.pattern, new_input) and length(new_input) == length(lesson.pattern) ->
        socket
        |> cancel_practice_timer()
        |> assign(:stage, {:lesson, index, :navigation})
        |> assign(:input, [])
        |> assign(:prompt, navigation_prompt(socket.assigns.lessons, index))
        |> assign(:info, "Correct!")
        |> assign(:error, nil)
        |> assign(:show_hint, false)
        |> maybe_mark_complete(index)

      matches_prefix?(lesson.pattern, new_input) ->
        socket
        |> assign(:input, new_input)
        |> assign(:error, nil)
        |> restart_practice_timer(index)

      true ->
        socket
        |> assign(:input, [])
        |> assign(:prompt, "Look at the image and try again")
        |> assign(:show_hint, true)
        |> assign(:error, :error)
        |> restart_practice_timer(index)
    end
  end

  defp handle_navigation(socket, index, :dot) do
    lessons = socket.assigns.lessons

    if index + 1 < length(lessons) do
      socket
      |> assign(:stage, {:lesson, index + 1, :learning})
      |> assign(:input, [])
      |> assign(:prompt, lesson_prompt(lessons, index + 1, :learning))
      |> assign(:info, nil)
      |> assign(:show_hint, false)
    else
      socket
      |> assign(
        :final_message,
        "Congratulations! You completed the tutorial! Press Dash on the main page to join a Competition!"
      )
      |> assign(:prompt, "Press Dash to revisit the previous lesson, Long-Dash to return home")
      |> assign(:stage, {:lesson, index, :navigation})
    end
  end

  defp handle_navigation(socket, index, :dash) do
    cond do
      index > 0 ->
        socket
        |> assign(:stage, {:lesson, index - 1, :learning})
        |> assign(:input, [])
        |> assign(:prompt, lesson_prompt(socket.assigns.lessons, index - 1, :learning))
        |> assign(:info, nil)
        |> assign(:show_hint, false)

      true ->
        socket
        |> assign(:stage, {:intro, :dash})
        |> assign(:input, [])
        |> assign(:prompt, "Long press to enter Dash")
        |> assign(:info, "You're back at the basics. Dot heads to lessons again.")
    end
  end

  defp handle_navigation(socket, _index, _symbol), do: socket

  defp flash_error(socket, message) do
    socket
    |> assign(:error, :error)
    |> assign(:prompt, message)
  end

  ## Prompt helpers -------------------------------------------------------------

  defp lesson_prompt(lessons, index, :learning) do
    lesson = Enum.at(lessons, index)
    "Input the Morse code for the letter \"#{lesson.letter}\""
  end

  defp practice_prompt(letter) do
    "Try! Input the Morse code for the letter \"#{letter}\""
  end

  defp navigation_prompt(lessons, index) do
    if index + 1 < length(lessons) do
      "Correct! Press Dot to continue, Dash to previous page, Long-Dash to Exit"
    else
      "Correct! Press Dot to celebrate, Dash to previous page, Long-Dash to exit"
    end
  end

  defp intro_image({:intro, :dot}), do: "/images/dot.svg"
  defp intro_image({:intro, :dash}), do: "/images/dash.svg"

  defp current_lesson(lessons, {:lesson, index, _stage}) do
    Enum.at(lessons, index)
  end

  defp matches_prefix?(pattern, input) do
    Enum.take(pattern, length(input)) == input
  end

  defp schedule_intro_advance(socket) do
    Process.send_after(self(), :advance_from_intro, 3_000)
    socket
  end

  defp restart_practice_timer(socket, index) do
    socket
    |> cancel_practice_timer()
    |> assign(:practice_timer_ref, schedule_practice_timeout(index))
  end

  defp schedule_practice_timeout(index) do
    Process.send_after(self(), {:practice_timeout, index}, @practice_timeout)
  end

  defp cancel_practice_timer(%{assigns: %{practice_timer_ref: nil}} = socket), do: socket

  defp cancel_practice_timer(%{assigns: %{practice_timer_ref: ref}} = socket) do
    Process.cancel_timer(ref)
    assign(socket, :practice_timer_ref, nil)
  end

  defp intro_stage?({:intro, _}), do: true
  defp intro_stage?(_), do: false

  defp lesson_learning?({:lesson, _index, :learning}), do: true
  defp lesson_learning?(_), do: false

  defp maybe_mark_complete(socket, index) do
    if index + 1 == length(socket.assigns.lessons) do
      assign(
        socket,
        :final_message,
        "Congratulations! You completed the tutorial! Press Dash on the main page to join a Competition!"
      )
    else
      socket
    end
  end
end
