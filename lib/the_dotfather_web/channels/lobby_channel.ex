defmodule TheDotfatherWeb.LobbyChannel do
  @moduledoc """
  Manages the matchmaking lobby.
  """

  use Phoenix.Channel

  alias TheDotfather.Matchmaker

  def join("lobby", _payload, socket) do
    {:ok, socket}
  end

  def handle_in("find_game", _payload, socket) do
    case Matchmaker.find_game(self(), socket.assigns.player) do
      {:paired, _id} -> :ok
      :queued -> push(socket, "queued", %{})
    end

    {:noreply, socket}
  end

  def handle_in("cancel_find", _payload, socket) do
    Matchmaker.cancel(self())
    push(socket, "queue_canceled", %{})
    {:noreply, socket}
  end

  def handle_info({:match_found, match_id, role}, socket) do
    push(socket, "match_found", %{match_id: match_id, role: Atom.to_string(role)})
    {:noreply, socket}
  end
end
