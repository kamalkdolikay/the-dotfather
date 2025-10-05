defmodule TheDotfather.Morse do
  @moduledoc """
  Helpers for working with Morse code symbols and patterns.
  """

  @type symbol :: :dot | :dash

  @alphabet %{
    "A" => [:dot, :dash],
    "B" => [:dash, :dot, :dot, :dot],
    "C" => [:dash, :dot, :dash, :dot],
    "D" => [:dash, :dot, :dot],
    "E" => [:dot],
    "F" => [:dot, :dot, :dash, :dot],
    "G" => [:dash, :dash, :dot],
    "H" => [:dot, :dot, :dot, :dot],
    "I" => [:dot, :dot],
    "J" => [:dot, :dash, :dash, :dash],
    "K" => [:dash, :dot, :dash],
    "L" => [:dot, :dash, :dot, :dot],
    "M" => [:dash, :dash],
    "N" => [:dash, :dot],
    "O" => [:dash, :dash, :dash],
    "P" => [:dot, :dash, :dash, :dot],
    "Q" => [:dash, :dash, :dot, :dash],
    "R" => [:dot, :dash, :dot],
    "S" => [:dot, :dot, :dot],
    "T" => [:dash],
    "U" => [:dot, :dot, :dash],
    "V" => [:dot, :dot, :dot, :dash],
    "W" => [:dot, :dash, :dash],
    "X" => [:dash, :dot, :dot, :dash],
    "Y" => [:dash, :dot, :dash, :dash],
    "Z" => [:dash, :dash, :dot, :dot]
  }

  @dot_tokens [".", "+", "dot"]
  @dash_tokens ["-", "_", "dash"]

  @spec pattern_for(String.t()) :: [symbol()]
  def pattern_for(letter) when is_binary(letter) do
    @alphabet
    |> Map.fetch!(String.upcase(letter))
  end

  def random_letters(from_letters, count) do
    from_letters
    |> Enum.map(&String.upcase/1)
    |> Enum.shuffle()
    |> Enum.take(count)
  end

  def random_word(from_letters, length) do
    letters =
      from_letters
      |> Enum.map(&String.upcase/1)

    case letters do
      [] ->
        ""

      _ ->
        for _ <- 1..length, into: [] do
          Enum.random(letters)
        end
        |> Enum.join()
    end
  end

  @spec encode_word(String.t()) :: [[symbol()]]
  def encode_word(word) do
    word
    |> String.upcase()
    |> String.replace(" ", "")
    |> String.graphemes()
    |> Enum.map(&pattern_for/1)
  end

  def flatten_pattern(pattern) do
    pattern
    |> Enum.map(fn
      list when is_list(list) -> list
      symbol -> [symbol]
    end)
    |> Enum.intersperse(:space)
    |> Enum.reduce([], fn
      :space, [] -> []
      :space, acc -> acc ++ [:space]
      symbols, acc -> acc ++ symbols
    end)
  end

  def pattern_to_string(pattern) do
    pattern
    |> flatten_pattern()
    |> Enum.map(fn
      :dot -> "."
      :dash -> "-"
      :space -> " "
    end)
    |> Enum.join()
  end

  def parse_input(input) when is_binary(input) do
    input
    |> String.trim()
    |> String.graphemes()
    |> Enum.reduce([], fn
      " ", acc -> if acc == [] or hd(Enum.reverse(acc)) == :space, do: acc, else: acc ++ [:space]
      token, acc when token in @dot_tokens -> acc ++ [:dot]
      token, acc when token in @dash_tokens -> acc ++ [:dash]
      _other, acc -> acc
    end)
    |> normalize_spaces()
  end

  def correct_answer?(expected_pattern, input) do
    expected_pattern
    |> flatten_pattern()
    |> Enum.reject(&(&1 == :space))
    |> Kernel.==(parse_input(input) |> Enum.reject(&(&1 == :space)))
  end

  defp normalize_spaces([]), do: []

  defp normalize_spaces(symbols) do
    symbols
    |> Enum.chunk_by(& &1)
    |> Enum.reduce([], fn
      [:space | _], acc ->
        case acc do
          [] -> acc
          [:space | _] -> acc
          _ -> acc ++ [:space]
        end

      chunk, acc ->
        acc ++ chunk
    end)
    |> drop_trailing_space()
  end

  defp drop_trailing_space(list) do
    case Enum.reverse(list) do
      [:space | rest] -> Enum.reverse(rest)
      _ -> list
    end
  end
end
