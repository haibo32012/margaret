defmodule Margaret.Stories.Story do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import EctoEnum, only: [defenum: 3]

  alias __MODULE__
  alias Margaret.{Accounts, Stars, Comments, Publications, Tags}
  alias Accounts.User
  alias Stars.Star
  alias Comments.Comment
  alias Publications.Publication
  alias Tags.Tag

  @type t :: %Story{}

  @permitted_attrs [
    :content,
    :author_id,
    :audience,
    :publication_id,
    :published_at,
    :license,
  ]

  @required_attrs [
    :content,
    :author_id,
    :audience,
    :license,
  ]

  @update_permitted_attrs [
    :content,
    :audience,
    :publication_id,
    :published_at,
    :license,
  ]

  @update_required_attrs []
  
  @unique_hash_length 16

  defenum StoryAudience,
    :story_audience,
    [:all, :members, :unlisted]

  defenum StoryLicense,
    :story_license,
    [:all_rights_reserved, :public_domain]

  schema "stories" do
    # `content` isn't plaintext, it contains metadata, so we store it as a map (JSON).
    field :content, :map
    belongs_to :author, User
    field :unique_hash, :string

    field :audience, StoryAudience
    field :published_at, :naive_datetime

    field :license, StoryLicense

    has_many :stars, Star
    has_many :comments, Comment

    belongs_to :publication, Publication

    many_to_many :tags, Tag, join_through: "story_tags", on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(attrs), do: changeset(%Story{}, attrs)

  @doc false
  def changeset(%Story{id: nil} = story, attrs) do
    story
    |> cast(attrs, @permitted_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:author_id)
    |> foreign_key_constraint(:publication_id)
    |> maybe_put_tags(attrs)
    |> maybe_put_unique_hash()
  end

  def changeset(%Story{} = story, attrs), do: update_changeset(story, attrs)

  def update_changeset(%Story{} = story, attrs) do
    story
    |> cast(attrs, @permitted_attrs_update)
    |> validate_required(@required_attrs_update)
    |> foreign_key_constraint(:publication_id)
    |> maybe_put_tags(attrs)
  end

  defp maybe_put_tags(%Ecto.Changeset{} = changeset, %{tags: tags} = attrs) do
    put_assoc(changeset, :tags, tags)
  end

  defp maybe_put_tags(%Ecto.Changeset{} = changeset, _attrs), do: changeset

  defp maybe_put_unique_hash(%Ecto.Changeset{data: %{unique_hash: nil}} = changeset) do
    put_change(changeset, :unique_hash, generate_hash())
  end

  defp maybe_put_unique_hash(changeset), do: changeset

  defp generate_hash() do
    :sha512
    |> :crypto.hash(UUID.uuid4())
    |> Base.encode32()
    |> String.slice(0..@unique_hash_length)
    |> String.downcase()
  end
end
