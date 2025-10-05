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

  def flash_class(nil), do: "text-lg text-slate-200"
  def flash_class(:error), do: "text-lg font-semibold text-rose-300 animate-pulse"

  def symbol_glyph(:dot), do: "."
  def symbol_glyph(:dash), do: "-"

  def symbol_class(:dot), do: "text-emerald-300"
  def symbol_class(:dash), do: "text-cyan-300"

  def resolve_lesson(lessons, {:lesson, index, _stage}) when is_list(lessons) do
    Enum.at(lessons, index)
  end

  def resolve_lesson(_lessons, _stage), do: nil
end
