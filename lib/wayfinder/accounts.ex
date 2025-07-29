defmodule Wayfinder.Accounts do
  @moduledoc """
  Provides functions related to user accounts, including user registration, user profile editing, authentication, and session management.
  """

  import Ecto.Query
  import Ecto.Changeset

  alias Wayfinder.Accounts.User
  alias Wayfinder.Accounts.UserNotifier
  alias Wayfinder.Accounts.UserToken
  alias Wayfinder.Repo

  @typedoc """
  A map value shape related to the attributes used when creating a
  `Wayfinder.Accounts.User` entity via the `create_user/1` function.
  """
  @type create_user_attrs :: %{
          optional(:email) => String.t(),
          optional(:password) => String.t(),
          optional(:password_confirmation) => String.t()
        }

  @typedoc """
  A map value shape related to the attributes used when updating a
  `Wayfinder.Accounts.User` entity via the `update_user_email/2` function.
  """
  @type update_user_email_attrs :: %{
          optional(:email) => String.t()
        }

  @doc """
  Returns an atom-based `t:create_user_attrs/0` value from an incoming (possibly
  string-based) Map value, suitable for the `create_user/1` function.

  ## Examples

      iex> cast_create_user_attrs(%{"email" => "foo@example.com", "password" => "password", "password_confirmation" => "password"})
      %{email: "foo@example.com", password: "password", password_confirmation: "password"}

      iex> cast_create_user_attrs(%{email: "foo@example.com", admin: "true"})
      %{email: "foo@example.com", password: nil, password_confirmation: nil}
  """
  @spec cast_create_user_attrs(input :: map()) :: create_user_attrs()
  def cast_create_user_attrs(input) do
    %{
      email: get_map_value(input, :email),
      password: get_map_value(input, :password),
      password_confirmation: get_map_value(input, :password_confirmation)
    }
  end

  @doc """
  Returns an atom-based `t:update_user_email_attrs/0` value from an incoming (possibly
  string-based) Map value, suitable for the `update_user_email/2` function.

  ## Examples

      iex> cast_update_user_email_attrs(%{"email" => "foo@example.com", "extra" => "ignored"})
      %{email: "foo@example.com"}
  """
  @spec cast_update_user_email_attrs(input :: map()) :: update_user_email_attrs()
  def cast_update_user_email_attrs(input) do
    %{email: get_map_value(input, :email)}
  end

  @doc """
  Creates a `Wayfinder.Accounts.User` entity signifying a new user registration.
  """
  @spec create_user(create_user_attrs()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_user(attrs) do
    attrs
    |> create_user_changeset()
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` appropriate for tracking attributes related to
  creating a `Wayfinder.Accounts.User` entity.
  """
  @spec create_user_changeset(attrs :: create_user_attrs()) :: Ecto.Changeset.t()
  def create_user_changeset(attrs \\ %{}) do
    %User{}
    |> cast(attrs, [:email, :password])
    |> User.validate_email()
    |> User.validate_password()
  end

  @doc """
  Deletes the given user session token.
  """
  @spec delete_user_session_token(token :: String.t()) :: :ok
  def delete_user_session_token(token) when is_binary(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  @doc """
  Delivers the update email instructions to the given user.
  """
  @spec deliver_user_update_email_instructions(
          user :: User.t(),
          current_email :: String.t(),
          update_email_url_fun :: (String.t() -> String.t())
        ) :: {:ok, Swoosh.Email.t()}
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)

    url = update_email_url_fun.(encoded_token)

    # Going to match on an assumed success result, but ultimately we should
    # change this to an Oban job.
    {:ok, _email} = UserNotifier.deliver_update_email_instructions(user, url)
  end

  @doc """
  Creates, persists, and returns a session token for the given `Wayfinder.Accounts.User` entity.
  """
  @spec generate_user_session_token(user :: User.t()) :: token :: String.t()
  def generate_user_session_token(%User{} = user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Returns a `Wayfinder.Accounts.User` entity for the given identity.

  Raises `Ecto.NoResultsError` if no entity exists.
  """
  @spec get_user!(id :: User.id()) :: User.t()
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Returns a `Wayfinder.Accounts.User` entity for the given email address.
  """
  @spec get_user_by_email(email :: String.t()) :: User.t() | nil
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Returns a `Wayfinder.Accounts.User` entity for the given email address
  and password.
  """
  @spec get_user_by_email_and_password(
          email :: String.t(),
          password :: String.t()
        ) :: User.t() | nil
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Returns a `Wayfinder.Accounts.User` entity for the given session token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  @spec get_user_by_session_token(token :: String.t()) ::
          {user :: User.t(), token_inserted_at :: DateTime.t()} | nil
  def get_user_by_session_token(token) do
    query =
      from token in UserToken.by_token_and_context_query(token, "session"),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(14, "day"),
        select: {%{user | authenticated_at: token.authenticated_at}, token.inserted_at}

    Repo.one(query)
  end

  @doc """
  Returns `true` when the user is considered recently authenticated.

  Recently is defined by default as the last authentication was done no further
  than 20 minutes ago.

  The time limit in minutes can be given as second argument.
  """
  @spec recently_authenticated?(User.t(), minutes :: integer()) :: boolean()
  def recently_authenticated?(user, minutes \\ -20)

  def recently_authenticated?(%User{authenticated_at: authenticated_at}, minutes)
      when is_struct(authenticated_at, DateTime) do
    minutes_from_now = DateTime.utc_now() |> DateTime.add(minutes, :minute)
    DateTime.after?(authenticated_at, minutes_from_now)
  end

  def recently_authenticated?(_user, _minutes), do: false

  @doc """
  Updates a `Wayfinder.Accounts.User` entity's email using a change email token.

  If the token matches, the user email is updated and the token is deleted.
  """
  @spec update_user_email(user :: User.t(), token :: String.t()) ::
          {:ok, User.t()} | {:error, :transaction_aborted}
  def update_user_email(%User{} = user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` appropriate for tracking attributes related to
  updating a `Wayfinder.Accounts.User` entity's email.
  """
  @spec update_user_email_changeset(
          user :: User.t(),
          attrs :: update_user_email_attrs()
        ) :: User.changeset()
  def update_user_email_changeset(%User{} = user, attrs \\ %{}) do
    user
    |> cast(attrs, [:email])
    |> User.validate_email()
  end

  ## ORDERED

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Options

  * `:action` - An optional atom applied to the changeset's `:action` attribute. Useful for forms that
    look to a changeset's action to influence form presentation.
  """
  def update_user_password_changeset(%User{} = user, attrs \\ %{}, opts \\ []) do
    opts = Keyword.validate!(opts, action: nil)

    changeset =
      user
      |> cast(attrs, [:password])
      |> User.validate_password()

    # DRY
    if opts[:action] do
      Map.put(changeset, :action, opts[:action])
    else
      changeset
    end
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.
  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end

  # TODO: Maybe move this to a helper?
  defp get_map_value(map, key) do
    map[key] || map[Atom.to_string(key)]
  end
end
