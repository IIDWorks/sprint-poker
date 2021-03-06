defmodule SprintPoker.Web.GameChannel do
  @moduledoc """
  Game channel messages hadling
  """
  use Phoenix.Channel

  alias SprintPoker.UserOperations
  alias SprintPoker.SocketOperations
  alias SprintPoker.StateOperations
  alias SprintPoker.TicketOperations
  alias SprintPoker.GameOperations

  def join("game:" <> game_id, message, socket) do
    UserOperations.connect(socket.assigns.user_id, game_id)

    send(self(), {:after_join, message})
    {:ok, socket}
  end

  def terminate(_message, socket) do
    "game:" <> game_id = socket.topic

    game = socket.assigns.user_id
           |> UserOperations.disconnect(game_id)
           |> GameOperations.preload

    socket |> broadcast("game", %{game: game})
  end

  def handle_info({:after_join, _message}, socket) do
    {game, user} = SocketOperations.get_game_and_user(socket)

    game = game |> GameOperations.preload

    socket |> broadcast("game", %{game: game})
    socket
    |> push("state", %{state: StateOperations.hide_votes(game.state, user)})

    {:noreply, socket}
  end

  def handle_in("ticket:create", message, socket) do
    {game, user} = SocketOperations.get_game_and_user(socket)

    if SocketOperations.is_owner?(user, game) do
      TicketOperations.create(message["ticket"], game)

      game = game |> GameOperations.preload
      socket |> broadcast("game", %{game: game})
    end
    {:noreply, socket}
  end

  def handle_in("ticket:delete", message, socket) do
    {game, user} = SocketOperations.get_game_and_user(socket)

    if SocketOperations.is_owner?(user, game) do
      TicketOperations.delete(message["ticket"])

      game = game |> GameOperations.preload

      socket |> broadcast("game", %{game: game})
    end
    {:noreply, socket}
  end

  def handle_in("ticket:update", message, socket) do
    {game, user} = SocketOperations.get_game_and_user(socket)
    ticket = TicketOperations.get_by_id(message["ticket"]["id"])

    if SocketOperations.is_owner?(user, game) do
       TicketOperations.update(ticket, message["ticket"])

      game = game |> GameOperations.preload

      socket |> broadcast("game", %{game: game})
    end
    {:noreply, socket}
  end

  def handle_in("state:update", message, socket) do
    {game, user} = SocketOperations.get_game_and_user(socket)
    game = game |> StateOperations.preload()

    if SocketOperations.is_owner?(user, game) do
      state = StateOperations.update(game.state, message["state"])
      socket |> broadcast("state", %{state: state})
    end
    {:noreply, socket}
  end

  def handle_in("state:update:vote", message, socket) do
    {game, user} = SocketOperations.get_game_and_user(socket)
    game = game |> StateOperations.preload()

    state = StateOperations.update(game.state,
      %{votes: Map.put(game.state.votes, user.id, message["vote"]["points"])})

    socket |> broadcast("state", %{state: state})
    {:noreply, socket}
  end

  intercept ["state"]
  def handle_out("state", message, socket) do
    user = UserOperations.get_by_id(socket.assigns.user_id)

    socket
    |> push("state", %{state: StateOperations.hide_votes(message.state, user)})

    {:noreply, socket}
  end
end
