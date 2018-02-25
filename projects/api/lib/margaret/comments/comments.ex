defmodule Margaret.Comments do
  @moduledoc """
  The Comments context.
  """

  import Ecto.Query
  alias Margaret.Repo

  alias Margaret.{
    Accounts,
    Stories,
    Comments
  }

  alias Accounts.User
  alias Stories.Story
  alias Comments.Comment

  @doc """
  Gets a comment by its id.

  ## Examples

      iex> get_comment(123)
      %Comment{}

      iex> get_comment(456)
      nil

  """
  @spec get_comment(String.t() | non_neg_integer) :: Comment.t() | nil
  def get_comment(id), do: Repo.get(Comment, id)

  @doc """
  Gets a comment by its id.

  Raises `Ecto.NoResultsError` if the comment does not exist.

  ## Examples

      iex> get_comment!(123)
      %Comment{}

      iex> get_comment!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_comment!(String.t() | non_neg_integer) :: Comment.t() | no_return
  def get_comment!(id), do: Repo.get!(Comment, id)

  @doc """
  Gets the story of a comment.
  """
  @spec get_story(Comment.t()) :: Story.t()
  def get_story(%Comment{} = comment) do
    comment
    |> Comment.preload_story()
    |> Map.get(:story)
  end

  @doc """
  Gets the author of a comment.
  """
  @spec get_author(Comment.t()) :: User.t()
  def get_author(%Comment{} = comment) do
    comment
    |> Comment.preload_author()
    |> Map.get(:author)
  end

  @doc """
  Gets the parent of a comment.
  """
  @spec get_parent(Comment.t()) :: User.t()
  def get_parent(%Comment{} = comment) do
    comment
    |> Comment.preload_parent()
    |> Map.get(:parent)
  end

  @doc """
  Gets the comment count of a commentable.

  ## Examples

<<<<<<< HEAD
  def get_comment_count(comment_id: comment_id) do
    query = from c in Comment,
      join: u in User, on: u.id == c.author_id,
      where: c.parent_id == ^comment_id,
      where: u.is_active == true,
      select: count(c.id)
  defp do_get_comment_count(query) do
    query =
      from(
        c in query,
        join: u in User,
        on: u.id == c.author_id,
        where: is_nil(u.deactivated_at),
        select: count(c.id)
      )

    Repo.one!(query)
  end
=======
      iex> get_comment_count([story: %Story{}])
      815
>>>>>>> 72c3be339335c278d767905641e321cdf69f6db0

      iex> get_comment_count([comment: %Comment{}])
      42

  """
  @spec get_comment_count(Keyword.t()) :: non_neg_integer
  def get_comment_count(clauses) do
    query =
      cond do
        Keyword.has_key?(clauses, :story) ->
          clauses
          |> Keyword.get(:story)
          |> Comment.by_story()

        Keyword.has_key?(clauses, :comment) ->
          clauses
          |> Keyword.get(:comment)
          |> Comment.by_parent()
      end

    query
    |> join(:inner, [c], u in assoc(c, :author))
    |> User.active()
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Returns `true` if the user can see the comment.
  `false` otherwise.
  """
  @spec can_see_comment?(Comment.t(), User.t()) :: boolean
  def can_see_comment?(%Comment{} = comment, %User{} = user) do
    comment
    |> get_story()
    |> Stories.can_see_story?(user)
  end

  @doc """
  Inserts a comment.
  """
  def insert_comment(attrs) do
    attrs
    |> Comment.changeset()
    |> Repo.insert()
  end

  @doc """
  Updates a comment.
  """
  def update_comment(%Comment{} = comment, attrs) do
    comment
    |> Comment.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a comment.
  """
  def delete_comment(%Comment{} = comment), do: Repo.delete(comment)
end
