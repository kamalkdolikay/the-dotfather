defmodule TheDotfatherWeb.TutorialLive do
  use TheDotfatherWeb, :live_view

  alias TheDotfather.Tutorial
  alias TheDotfatherWeb.TutorialLiveHTML

  @practice_timeout 4_000

  @impl true
  def mount(_params, _session, socket) do
    lessons = Tutorial.lessons()

    {:ok,
     socket
     |> assign(:lessons, lessons)
     |> assign(:stage, {:intro, :dot})
     |> assign(:input, [])
     |> assign(:prompt, "Tap to begin with a dot")
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
  def render(assigns), do: TutorialLiveHTML.tutorial(assigns)

  ## Stage handling -------------------------------------------------------------

  defp handle_symbol(socket, :long_dash) do
    case socket.assigns.stage do
      {:lesson, _index, stage} when stage in [:learning, :practice, :navigation] ->
        push_navigate(socket, to: ~p"/")

      {:intro, :hold} ->
        advance_to_first_lesson(socket)

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
      {:intro, :hold} -> handle_intro_hold(socket, symbol)
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
    |> assign(:prompt, "Press and hold a little longer for a dash")
    |> assign(:error, nil)
  end

  defp handle_intro_dot(socket, _symbol) do
    flash_error(socket, "Quick tap for a dot")
  end

  defp handle_intro_dash(socket, :dash) do
    socket
    |> assign(:stage, {:intro, :hold})
    |> assign(:input, [])
    |> assign(:prompt, "Hold for 3 seconds to continue")
    |> assign(:info, nil)
    |> assign(:error, nil)
  end

  defp handle_intro_dash(socket, _symbol) do
    flash_error(socket, "Hold a little longer for a dash")
  end

  defp handle_intro_hold(socket, _symbol) do
    flash_error(socket, "Hold for 3 seconds to continue")
  end

  defp advance_to_first_lesson(socket) do
    lessons = socket.assigns.lessons || []

    if lessons == [] do
      push_navigate(socket, to: ~p"/")
    else
      socket
      |> assign(:stage, {:lesson, 0, :learning})
      |> assign(:input, [])
      |> assign(:prompt, lesson_prompt(lessons, 0, :learning))
      |> assign(:info, nil)
      |> assign(:show_hint, false)
      |> assign(:error, nil)
    end
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
        |> assign(:prompt, "Press and hold a little longer for a dash")
        |> assign(:info, "Tap for dot training. Hold to keep practicing.")
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

  defp current_lesson(lessons, {:lesson, index, _stage}) do
    Enum.at(lessons, index)
  end

  defp matches_prefix?(pattern, input) do
    Enum.take(pattern, length(input)) == input
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
