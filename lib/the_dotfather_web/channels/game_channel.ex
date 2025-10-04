defmodule TheDotfatherWeb.GameChannel do
  @moduledoc """
  Relays game server updates to participating players.
  """

  use Phoenix.Channel

  alias TheDotfather.GameServer

  def join("game:" <> match_id, _payload, socket) do
    user_id = socket.assigns.player.user_id

    case GameServer.join(match_id, user_id) do
      {:ok, snapshot} ->
        {:ok, snapshot, assign(socket, :match_id, match_id)}

      {:error, reason} ->
        {:error, %{reason: to_string(reason)}}
    end
  end

  def handle_in("answer", %{"morse" => morse}, socket) do
    case GameServer.submit_answer(socket.assigns.match_id, socket.assigns.player.user_id, morse) do
      {:ok, status} ->
        push(socket, "answer_feedback", %{result: Atom.to_string(status)})
        {:noreply, socket}

      {:error, reason} ->
        push(socket, "answer_feedback", %{result: "error", reason: Atom.to_string(reason)})
        {:noreply, socket}
    end
  end

  def handle_in("leave", _payload, socket) do
    GameServer.leave(socket.assigns.match_id, socket.assigns.player.user_id)
    {:noreply, socket}
  end
end
