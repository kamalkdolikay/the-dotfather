defmodule TheDotfatherWeb.UserSocket do
  use Phoenix.Socket

  channel "lobby", TheDotfatherWeb.LobbyChannel
  channel "game:*", TheDotfatherWeb.GameChannel

  @impl true
  def connect(%{"user_id" => user_id, "nickname" => nickname}, socket, _info)
      when byte_size(user_id) > 0 and byte_size(nickname) > 0 do
    {:ok, assign(socket, :player, %{user_id: user_id, nickname: nickname})}
  end

  def connect(_params, _socket, _info), do: :error

  @impl true
  def id(_socket), do: nil
end
