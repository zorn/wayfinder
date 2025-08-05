defmodule Wayfinder.Accounts.User do
  @moduledoc """
  TODO
  """

  use Ecto.Schema
  import Ecto.Changeset

  @typedoc """
  A repo-sourced `Wayfinder.Accounts.User` entity.
  """
  @type t() :: %__MODULE__{
          id: id(),
          email: String.t(),
          hashed_password: String.t(),
          confirmed_at: DateTime.t() | nil,
          authenticated_at: DateTime.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @typedoc """
  An `Ecto.Changeset` for a repo-sourced `Wayfinder.Accounts.User` entity.
  """
  @type changeset() :: Ecto.Changeset.t(t())

  @typedoc """
  The identity value type of a `Wayfinder.Accounts.User` entity.
  """
  @type id() :: Ecto.UUID.t()

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime_usec
    field :authenticated_at, :utc_datetime, virtual: true

    timestamps(type: :utc_datetime_usec)
  end

  def validate_email(%Ecto.Changeset{} = changeset) do
    changeset
    |> validate_required([:email])
    # FIXME: This currently allows values like `1@2` which doesn't seem valid.
    # Update this when I'm cleaning up the tests.
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    # Should the database column be updated from `citext` to included the length expectation?
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Wayfinder.Repo)
    |> unique_constraint(:email)
  end

  def validate_password(%Ecto.Changeset{} = changeset) do
    changeset
    |> validate_required([:password])
    # It is important to validate the length of the password, as long passwords
    # may be very expensive to hash for certain algorithms.
    |> validate_length(:password, min: 12, max: 72)
    |> validate_confirmation(:password, message: "does not match password")
    |> maybe_hash_password()
  end

  defp maybe_hash_password(%Ecto.Changeset{} = changeset) do
    password_value = get_change(changeset, :password)

    if password_value && changeset.valid? do
      hashed_password_value = Argon2.hash_pwd_salt(password_value)

      changeset
      |> put_change(:hashed_password, hashed_password_value)
      # Once we have the hashed password, we should delete the plaintext password
      # so it is no longer in memory.
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end

  # TODO: Move this out of the schema file?
  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Argon2.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Wayfinder.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Argon2.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Argon2.no_user_verify()
    false
  end
end
