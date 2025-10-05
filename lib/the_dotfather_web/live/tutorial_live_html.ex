defmodule TheDotfatherWeb.TutorialLiveHTML do
  use TheDotfatherWeb, :html

  alias TheDotfather.Morse

  embed_templates "tutorial_live_html/*"

  def intro_stage?({:intro, _}), do: true
  def intro_stage?(_), do: false

  def lesson_learning?({:lesson, _index, :learning}), do: true
  def lesson_learning?(_), do: false

  def intro_image({:intro, :dot}), do: "/images/dot.svg"
  def intro_image({:intro, :dash}), do: "/images/dash.svg"

  def flash_class(nil), do: "lesson-panel__prompt-text"
  def flash_class(:error), do: "text-lg font-semibold text-rose-300 animate-pulse"

  def symbol_glyph(:dot), do: "."
  def symbol_glyph(:dash), do: "-"

  def symbol_class(:dot), do: "text-emerald-300"
  def symbol_class(:dash), do: "text-cyan-300"

  def lesson_monitor_classes(stage, show_hint) do
    [
      "lesson-monitor",
      if(intro_stage?(stage), do: "lesson-monitor--intro", else: nil),
      if(intro_stage?(stage), do: nil, else: "lesson-monitor--lesson"),
      if(lesson_show_art?(stage, show_hint), do: nil, else: "lesson-monitor--hide-art")
    ]
    |> Enum.reject(&is_nil/1)
  end

  def lesson_show_art?({:lesson, _idx, :learning}, _show_hint), do: true
  def lesson_show_art?({:lesson, _idx, :navigation}, _show_hint), do: true
  def lesson_show_art?({:lesson, _idx, :practice}, show_hint), do: show_hint
  def lesson_show_art?(_, _), do: false

  def resolve_lesson(lessons, {:lesson, index, _stage}) when is_list(lessons) do
    Enum.at(lessons, index)
  end

  def resolve_lesson(_lessons, _stage), do: nil
end
