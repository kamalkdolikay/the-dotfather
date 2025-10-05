defmodule TheDotfather.Tutorial do
  @moduledoc """
  Provides configuration-backed tutorial content for the Morse lessons.
  """

  alias TheDotfather.Morse

  @type lesson :: %{
          letter: String.t(),
          pattern: [Morse.symbol()],
          image: String.t()
        }

  @default_letters [
    %{letter: "E", pattern: [:dot], image: "/images/letters/E.svg", word: "Egg"},
    %{letter: "T", pattern: [:dash], image: "/images/letters/T.svg", word: "Tree"},
    %{letter: "I", pattern: [:dot, :dot], image: "/images/letters/I.svg", word: "Insect"},
    %{letter: "M", pattern: [:dash, :dash], image: "/images/letters/M.svg", word: "Mask"},
    %{letter: "A", pattern: [:dot, :dash], image: "/images/letters/A.svg", word: "Avocado"},
    %{letter: "S", pattern: [:dot, :dot, :dot], image: "/images/letters/S.svg", word: "Signal"}
  ]

  @spec lessons() :: [lesson()]
  def lessons do
    Application.get_env(:the_dotfather, __MODULE__, letters: @default_letters)
    |> Keyword.get(:letters, @default_letters)
    |> Enum.map(&normalise/1)
  end

  @spec lookup(String.t()) :: lesson()
  def lookup(letter) do
    letter = String.upcase(letter)

    lessons()
    |> Enum.find(fn %{letter: l} -> l == letter end)
    |> case do
      nil ->
        %{
          letter: letter,
          pattern: Morse.pattern_for(letter),
          image: "/images/tutorial/placeholder.svg",
          word: nil
        }

      lesson ->
        lesson
    end
  end

  defp normalise(%{letter: letter, pattern: pattern} = lesson) when is_binary(letter) do
    pattern = Enum.map(pattern, &normalize_symbol/1)
    image = Map.get(lesson, :image, "/images/tutorial/placeholder.svg")
    word = Map.get(lesson, :word)

    %{letter: String.upcase(letter), pattern: pattern, image: image, word: word}
  end

  defp normalize_symbol(symbol) when symbol in [:dot, :dash], do: symbol
  defp normalize_symbol(:space), do: :space

  defp normalize_symbol(other) when is_binary(other) do
    case String.downcase(other) do
      "dot" -> :dot
      "dash" -> :dash
      _ -> raise ArgumentError, "invalid Morse symbol: #{inspect(other)}"
    end
  end
end
