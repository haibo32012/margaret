defmodule Margaret.Publications do
  @moduledoc """
  The Publications context.
  """

  import Ecto.Query
  alias Ecto.Multi

  alias Margaret.{Repo, Accounts, Stories, Publications, Tags}
  alias Stories.Story
  alias Publications.{Publication, PublicationMembership, PublicationInvitation}
  alias Accounts.User

  @doc """
  Gets a publication by its id.

  ## Examples

      iex> get_publication(123)
      %Publication{}

      iex> get_publication(456)
      nil

  """
  def get_publication(id), do: Repo.get(Publication, id)

  @doc """
  Gets a publication by its name.

  ## Examples

      iex> get_publication_by_name("publication123")
      %Publication{}

      iex> get_publication_by_name("publication456")
      nil

  """
  def get_publication_by_name(name), do: Repo.get_by(Publication, name: name)

  @doc """
  Gets the role of a member of a publication.
  Returns `nil` if the user is not a member.

  ## Examples

      iex> get_publication_member_role(123, 123)
      :owner

      iex> get_publication_member_role(123, 456)
      nil

  """
  @spec get_publication_member_role(any, any) :: atom | nil
  def get_publication_member_role(publication_id, member_id) do
    case get_publication_membership_by_publication_and_member(publication_id, member_id) do
      %PublicationMembership{role: role} -> role
      nil -> nil
    end
  end

  @doc """
  Returns the member count of the publication.
  """
  def get_member_count(publication_id) do
    query = from pm in PublicationMembership,
      where: pm.publication_id == ^publication_id,
      select: count(pm.id)

    Repo.one!(query)
  end

  @doc """
  Returns the story count of the publication.
  """
  def get_story_count(publication_id) do
    query = from s in Story,
      where: s.publication_id == ^publication_id,
      select: count(s.id)

    Repo.one!(query)
  end

  def check_role(publication_id, user_id, permitted_roles \\ []) do
    get_publication_member_role(publication_id, user_id) in permitted_roles
  end

  @doc """
  Returns true if the user is a member
  of the publication. False otherwise.

  ## Examples

      iex> publication_member?(123, 123)
      true

      iex> publication_member?(123, 456)
      false

  """
  @spec publication_member?(any, any) :: boolean
  def publication_member?(publication_id, user_id) do
    publication_id
    |> get_publication_member_role(user_id)
    |> do_publication_member?()
  end

  defp do_publication_member?(role) when not is_nil(role), do: true
  defp do_publication_member?(_), do: false

  def publication_editor?(publication_id, user_id) do
    check_role(publication_id, user_id, [:editor])
  end

  @doc """
  Returns true if the user is an admin
  of the publication. False otherwise.

  ## Examples

      iex> publication_admin?(123, 123)
      true

      iex> publication_admin?(123, 456)
      false

  """
  @spec publication_admin?(any, any) :: boolean
  def publication_admin?(publication_id, user_id) do
    check_role(publication_id, user_id, [:owner, :admin])
  end

  @doc """
  Returns true if the user is the owner
  of the publication. False otherwise.

  ## Examples

      iex> publication_owner?(123, 123)
      true

      iex> publication_owner?(123, 456)
      false

  """
  @spec publication_owner?(any, any) :: boolean
  def publication_owner?(publication_id, user_id) do
    check_role(publication_id, user_id, [:owner])
  end

  @doc """
  Returns true if the user can write stories for the publication.
  False otherwise.

  ## Examples

      iex> can_write_stories?(123, 123)
      true

      iex> can_write_stories?(123, 456)
      false

  """
  @spec can_write_stories?(any, any) :: boolean
  def can_write_stories?(publication_id, user_id) do
    check_role(publication_id, user_id, [:owner, :admin, :editor, :writer])
  end

  @doc """
  Returns true if the user can edit stories for the publication.
  False otherwise.

  ## Examples

      iex> can_edit_stories?(123, 123)
      true

      iex> can_edit_stories?(123, 456)
      false

  """
  @spec can_edit_stories?(any, any) :: boolean
  def can_edit_stories?(publication_id, user_id) do
    check_role(publication_id, user_id, [:owner, :admin, :editor])
  end

  @doc """
  Returns true if the user can see the invitations sent by the publication.
  False otherwise.

  ## Examples

      iex> can_see_invitations?(123, 123)
      true

      iex> can_see_invitations?(123, 456)
      false

  """
  @spec can_see_invitations?(any, any) :: boolean
  def can_see_invitations?(publication_id, user_id) do
    check_role(publication_id, user_id, [:owner, :admin])
  end

  @doc """
  Returns true if the user can update the publication information.
  False otherwise.

  ## Examples

      iex> can_update_publication?(123, 123)
      true

      iex> can_update_publication?(123, 456)
      false

  """
  @spec can_update_publication?(any, any) :: boolean
  def can_update_publication?(publication_id, user_id) do
    check_role(publication_id, user_id, [:owner, :admin])
  end

  @doc """
  Creates a publication.
  """
  def insert_publication(%{tags: tags} = attrs) do
    Multi.new()
    |> Multi.run(:tags, fn _ -> {:ok, Tags.insert_and_get_all_tags(tags)} end)
    |> do_insert_publication(attrs)
  end

  def insert_publication(attrs), do: do_insert_publication(Multi.new(), attrs)

  defp do_insert_publication(multi, %{owner_id: owner_id} = attrs) do
    multi
    |> Multi.run(:publication, &upsert_publication_fn(%Publication{}, attrs, &1))
    |> Multi.run(:membership, &insert_owner(&1, owner_id))
    |> Repo.transaction()
  end

  def update_publication(%Publication{} = publication, %{tags: tags} = attrs) do
    Multi.new()
    |> Multi.run(:tags, fn _ -> {:ok, Tags.insert_and_get_all_tags(tags)} end)
    |> do_update_publication(publication, attrs)
  end

  def update_publication(%Publication{} = publication, attrs) do
    do_update_publication(Multi.new(), publication, attrs)
  end

  defp do_update_publication(multi, publication, attrs) do
    multi
    |> Multi.run(:publication, &upsert_publication_fn(publication, attrs, &1))
    |> Repo.transaction()
  end

  defp upsert_publication_fn(publication, attrs, %{tags: tags}) do
    attrs_with_tags = Map.put(attrs, :tags, tags)

    publication
    |> Repo.preload(:tags)
    |> upsert_publication_fn(attrs_with_tags)
  end

  defp upsert_publication_fn(publication, attrs, _), do: upsert_publication_fn(publication, attrs)

  defp upsert_publication_fn(publication, attrs) do
    publication
    |> Publication.changeset(attrs)
    |> Repo.insert_or_update()
  end

  defp insert_owner(%{publication: %{id: publication_id}}, owner_id) do
    insert_publication_membership(
      %{role: :owner, member_id: owner_id, publication_id: publication_id})
  end

  @doc """
  Creates a publication membership.
  """
  def insert_publication_membership(attrs) do
    %PublicationMembership{}
    |> PublicationMembership.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a publication membership.
  """
  def get_publication_membership(id), do: Repo.get(PublicationMembership, id)

  def get_publication_owner(publication_id) do
    query = from u in User,
      join: pm in PublicationMembership, on: pm.member_id == u.id,
      where: pm.publication_id == ^publication_id and pm.role == ^:owner

    Repo.one!(query)
  end

  @doc """
  Gets a publication membership by publication and member ids.
  """
  def get_publication_membership_by_publication_and_member(publication_id, member_id) do
    Repo.get_by(PublicationMembership, publication_id: publication_id, member_id: member_id)
  end

  def delete_publication_membership(id) when is_integer(id) or is_binary(id) do
    Repo.delete(%PublicationMembership{id: id})
  end

  def delete_publication_membership(publication_id, member_id) do
    case get_publication_membership_by_publication_and_member(publication_id, member_id) do
      %PublicationMembership{id: id} -> delete_publication_membership(id)
      _ -> {:error, "User is not a member of the publication."}
    end
  end

  def delete_publication_membership(publication_id, member_id)

  @doc """
  Gets a publication invitation.
  """
  def get_publication_invitation(id), do: Repo.get(PublicationInvitation, id)

  @doc """
  Creates a publication invitation.
  """
  def insert_publication_invitation(attrs) do
    %PublicationInvitation{}
    |> PublicationInvitation.changeset(attrs)
    |> Repo.insert()
  end

  def update_publication_invitation(%PublicationInvitation{} = invitation, attrs) do
    invitation
    |> PublicationInvitation.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Accepts a publication invitation.
  Rejects all other invitations to the invitee.
  """
  def accept_publication_invitation(%PublicationInvitation{} = invitation) do
    invitation_changeset = PublicationInvitation.changeset(invitation, %{status: :accepted})
    reject_others_invitations = from i in PublicationInvitation,
      where: i.invitee_id == ^invitation.invitee_id and i.id != ^invitation.id,
      where: i.status == ^:pending,
      update: [set: [status: ^:rejected]]
    
    membership_attrs = %{
      role: invitation.role,
      publication_id: invitation.publication_id,
      member_id: invitation.invitee_id,
    }
    membership_changeset = PublicationMembership.changeset(
      %PublicationMembership{}, membership_attrs)


    Multi.new()
    |> Multi.update(:invitation, invitation_changeset)
    |> Multi.update_all(:reject_other_invitations, reject_others_invitations, [])
    |> Multi.insert(:membership, membership_changeset)
    |> Repo.transaction()
  end

  @doc """
  Rejects a publcation invitation.
  """
  def reject_publication_invitation(%PublicationInvitation{} = invitation) do
    update_publication_invitation(invitation, %{status: :rejected})
  end

  @doc """
  Kicks a member out of a publication.
  """
  def kick_publication_member(publication_id, member_id) do
    publication_id
    |> get_publication_membership_by_publication_and_member(member_id)
    |> case do
      %PublicationMembership{} = membership -> Repo.delete(membership)
      _ -> {:error, "User is not a member."}
    end
  end
end
