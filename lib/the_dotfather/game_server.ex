defmodule TheDotfather.GameServer do
  @moduledoc """
  State machine for a head-to-head Morse duel.
  """

  use GenServer

  alias TheDotfather.{Morse, Tutorial}
  alias TheDotfatherWeb.Endpoint

  @round_time_ms 10_000
  @letter_rounds 3
  @word_rounds 2

  ## Public API -----------------------------------------------------------------

  def start_link(%{match_id: id} = args) do
    GenServer.start_link(__MODULE__, args, name: via(id))
  end

  def via(id), do: {:via, Registry, {TheDotfather.GameRegistry, id}}

  def join(id, user_id), do: GenServer.call(via(id), {:join, user_id})

  def submit_answer(id, user_id, morse_answer),
    do: GenServer.call(via(id), {:answer, user_id, morse_answer})

  def leave(id, user_id), do: GenServer.cast(via(id), {:leave, user_id})

  ## GenServer callbacks ---------------------------------------------------------

  @impl true
  def init(%{match_id: id, p1: p1, p2: p2}) do
    tokens = MapSet.new([p1.user_id, p2.user_id])
    rounds = build_rounds()

    state = %{
      id: id,
      tokens: tokens,
      rounds: rounds,
      round_index: 0,
      timer_ref: nil,
      deadline_ms: nil,
      status: :waiting,
      players: %{
        p1.user_id => new_player(p1),
        p2.user_id => new_player(p2)
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:join, user_id}, _from, state) do
    with true <- MapSet.member?(state.tokens, user_id),
         player when not is_nil(player) <- state.players[user_id] do
      state = put_in(state, [:players, user_id, :joined?], true)
      state = maybe_start_round(state)
      {:reply, {:ok, snapshot_for(state, user_id)}, state}
    else
      _ -> {:reply, {:error, :forbidden}, state}
    end
  end

  @impl true
  def handle_call({:answer, user_id, morse_answer}, _from, state) do
    cond do
      state.status != :running ->
        {:reply, {:error, :not_running}, state}

      not Map.has_key?(state.players, user_id) ->
        {:reply, {:error, :unknown_player}, state}

      state.players[user_id].answered ->
        {:reply, {:ok, :already_answered}, state}

      true ->
        handle_answer(user_id, morse_answer, state)
    end
  end

  @impl true
  def handle_cast({:leave, user_id}, state) do
    Endpoint.broadcast(topic(state), "match_over", %{
      reason: "player_left",
      quitter_user_id: user_id,
      scores: scores_map(state.players),
      players: public_players(state)
    })

    {:stop, :normal, %{state | status: :finished}}
  end

  @impl true
  def handle_info(:round_timeout, state) do
    conclude_round(maybe_cancel_timer(state))
  end

  ## Internal helpers -----------------------------------------------------------

  defp new_player(%{user_id: user_id, nickname: nickname}) do
    %{
      id: user_id,
      nickname: nickname,
      joined?: false,
      answered: false,
      answer: nil,
      time_ms: nil,
      score: 0
    }
  end

  defp handle_answer(user_id, morse_answer, state) do
    question = current_round(state)
    now = now_ms()

    cond do
      state.deadline_ms && now > state.deadline_ms ->
        {:reply, {:ok, :too_late}, state}

      Morse.correct_answer?(question.pattern, morse_answer) ->
        elapsed = @round_time_ms - max(state.deadline_ms - now, 0)

        updated_state =
          state
          |> put_in([:players, user_id], %{
            state.players[user_id]
            | answered: true,
              answer: morse_answer,
              time_ms: elapsed
          })

        if everyone_answered?(updated_state) do
          {:reply, {:ok, :correct}, conclude_round(maybe_cancel_timer(updated_state))}
        else
          {:reply, {:ok, :correct}, updated_state}
        end

      true ->
        {:reply, {:ok, :incorrect}, state}
    end
  end

  defp maybe_start_round(%{status: :waiting} = state) do
    if all_joined?(state) do
      start_next_round(state)
    else
      state
    end
  end

  defp maybe_start_round(state), do: state

  defp start_next_round(state) do
    round_index = state.round_index + 1
    question = Enum.at(state.rounds, round_index - 1)

    state =
      state
      |> Map.put(:round_index, round_index)
      |> Map.put(:status, :running)
      |> Map.put(:players, reset_round_flags(state.players))

    start_ts = now_ms()
    deadline = start_ts + @round_time_ms

    ref = Process.send_after(self(), :round_timeout, @round_time_ms)

    Endpoint.broadcast(topic(state), "round_started", %{
      round: round_index,
      total_rounds: length(state.rounds),
      round_ms: @round_time_ms,
      server_now_ms: start_ts,
      deadline_ms: deadline,
      question: build_question_payload(question)
    })

    %{state | timer_ref: ref, deadline_ms: deadline}
  end

  defp conclude_round(state) do
    {state, results} = grade_round(state)

    Endpoint.broadcast(topic(state), "round_result", results)

    if state.round_index < length(state.rounds) do
      start_next_round(state)
    else
      final_state = %{state | status: :finished}
      Endpoint.broadcast(topic(state), "match_over", final_result(final_state))
      final_state
    end
  end

  defp grade_round(state) do
    question = current_round(state)

    graded =
      for {uid, player} <- state.players, into: %{} do
        correct? = player.answered && Morse.correct_answer?(question.pattern, player.answer || "")
        time_ms = player.time_ms || @round_time_ms
        base = if correct?, do: 100, else: 0
        bonus = if correct?, do: round((@round_time_ms - time_ms) / 100), else: 0

        %{correct?: correct?, time_ms: time_ms, gained: max(base + bonus, 0)}
        |> then(&{uid, &1})
      end

    updated_players =
      Enum.reduce(graded, state.players, fn {uid, result}, acc ->
        update_in(acc, [uid, :score], &(&1 + result.gained))
      end)

    payload = %{
      round: state.round_index,
      question: build_question_payload(question),
      per_player: graded,
      scores: scores_map(updated_players),
      players: public_players(%{state | players: updated_players})
    }

    {%{state | players: updated_players}, payload}
  end

  defp final_result(state) do
    scores = scores_map(state.players)
    {winner_id, _} = Enum.max_by(scores, fn {_uid, score} -> score end, fn -> {nil, 0} end)

    %{
      scores: scores,
      players: public_players(state),
      winner_user_id: winner_id
    }
  end

  defp build_rounds do
    lessons = Tutorial.lessons()
    lesson_letters = Enum.map(lessons, & &1.letter)

    letter_rounds =
      lesson_letters
      |> Morse.random_letters(@letter_rounds)
      |> Enum.map(fn letter ->
        lesson = Tutorial.lookup(letter)
        %{type: :letter, label: lesson.letter, pattern: [lesson.pattern]}
      end)

    word_rounds =
      for _ <- 1..@word_rounds do
        length = Enum.random(3..4)
        word = Morse.random_word(lesson_letters, length)
        %{type: :word, label: word, pattern: Morse.encode_word(word)}
      end

    letter_rounds ++ word_rounds
  end

  defp current_round(state) do
    Enum.at(state.rounds, state.round_index - 1)
  end

  defp build_question_payload(%{type: :letter, label: label} = question) do
    %{
      type: "letter",
      prompt: label,
      pattern_hint: Morse.pattern_to_string(question.pattern)
    }
  end

  defp build_question_payload(%{type: :word, label: label} = question) do
    %{
      type: "word",
      prompt: label,
      pattern_hint: Morse.pattern_to_string(question.pattern)
    }
  end

  defp reset_round_flags(players) do
    players
    |> Enum.map(fn {uid, player} ->
      {
        uid,
        %{player | answered: false, answer: nil, time_ms: nil}
      }
    end)
    |> Enum.into(%{})
  end

  defp snapshot_for(state, _user_id) do
    %{
      status: state.status,
      round: state.round_index,
      total_rounds: length(state.rounds),
      round_ms: @round_time_ms,
      remaining_ms: remaining_ms(state),
      server_now_ms: now_ms(),
      deadline_ms: state.deadline_ms,
      question: maybe_current_question(state),
      scores: scores_map(state.players),
      players: public_players(state)
    }
  end

  defp maybe_current_question(%{status: :running} = state) do
    build_question_payload(current_round(state))
  end

  defp maybe_current_question(_state), do: nil

  defp public_players(state) do
    for {uid, player} <- state.players, into: %{} do
      {uid, %{nickname: player.nickname, score: player.score}}
    end
  end

  defp scores_map(players) do
    for {uid, player} <- players, into: %{} do
      {uid, player.score}
    end
  end

  defp all_joined?(state) do
    Enum.all?(state.players, fn {_uid, player} -> player.joined? end)
  end

  defp everyone_answered?(state) do
    Enum.all?(state.players, fn {_uid, player} -> player.answered end)
  end

  defp remaining_ms(%{status: :running, deadline_ms: deadline}) when not is_nil(deadline) do
    max(deadline - now_ms(), 0)
  end

  defp remaining_ms(_), do: 0

  defp maybe_cancel_timer(%{timer_ref: nil} = state), do: state

  defp maybe_cancel_timer(%{timer_ref: ref} = state) do
    Process.cancel_timer(ref)
    %{state | timer_ref: nil}
  end

  defp topic(state), do: "game:#{state.id}"

  defp now_ms, do: System.monotonic_time(:millisecond)
end
