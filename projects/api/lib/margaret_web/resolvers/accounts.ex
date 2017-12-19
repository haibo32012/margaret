defmodule MargaretWeb.Resolvers.Accounts do
  @moduledoc """
  The Account GraphQL resolvers.
  """

  import Ecto.Query
  alias Absinthe.Relay

  alias MargaretWeb.Helpers
  alias Margaret.{Repo, Accounts, Stories}
  alias Stories.Story
  alias Accounts.User

  @doc """
  Resolves the currently logged in user.
  """
  def resolve_viewer(_, %{context: %{user: me}}), do: {:ok, me}
  def resolve_viewer(_, _), do: Helpers.GraphQLErrors.unauthorized()

  @doc """
  Resolves a user by its username.
  """
  def resolve_user(%{username: username}, _) do
    {:ok, Accounts.get_user_by_username(username)}
  end

  def resolve_user(%Story{author_id: author_id}, _, _) do
    {:ok, Accounts.get_user(author_id)}
  end

  @doc """
  Resolves a connection of stories of a parent.
  """
  def resolve_stories(%User{id: author_id}, args, _) do
    query = from s in Story,
      where: s.author_id == ^author_id,
      select: s

    Relay.Connection.from_query(query, &Repo.all/1, args)
  end

  @doc """
  Resolves a connection of users.
  """
  def resolve_users(args, _) do
    Relay.Connection.from_query(User, &Repo.all/1, args)
  end

  @doc """
  Resolves a user creation.
  """
  def resolve_create_user(args, _) do
  end

  @doc """
  Resolves if the user is the viewer.
  """
  def resolve_is_viewer(%User{id: user_id}, _, %{context: %{user: %{id: viewer_id}}}) do
    {:ok, user_id === viewer_id}
  end
end
