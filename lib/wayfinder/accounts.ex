defmodule Wayfinder.Accounts do
  @moduledoc """
  Provides functions related to user accounts, including user registration, user profile editing, authentication, and session management.
  """

  import Ecto.Query, warn: false

  alias Wayfinder.Accounts.User
  alias Wayfinder.Accounts.UserNotifier
  alias Wayfinder.Accounts.UserToken
  alias Wayfinder.Repo

  @doc """
  Returns an atom-based `t:create_user_attrs/0` value from an incoming (possibly
  string-based) Map value.

  This function is useful for call sites that need to convert a externally
  sourced string-keyed Map (think web form payloads) to a well shaped atom-keyed
  `attrs` argument appropriate for the `create_user/1` function.

  If the passed in argument is already using atom keys, it will be returned as
  is.

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
  Returns a `Wayfinder.Accounts.User` entity for the given identity.

  Raises `Ecto.NoResultsError` if no entity exists.
  """
  @spec get_user!(id :: User.id()) :: User.t()
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Creates a `Wayfinder.Accounts.User` entity.
  """
  @spec create_user(create_user_attrs()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_user(attrs) do
    attrs
    |> User.registration_changeset()
    |> Repo.insert()
  end

  @typedoc """
  A map value shape related to the attributes used when creating a
  `Wayfinder.Accounts.User` entity via the `create_user/1` function.
  """
  @type create_user_attrs :: %{
          optional(:email) => String.t(),
          optional(:password) => String.t(),
          optional(:password_confirmation) => String.t()
        }

  defp get_map_value(map, key) do
    map[key] || map[Atom.to_string(key)]
  end

  @doc """
  Returns a changeset appropriate for creating a new user.

  ## Options

  * `:action` - An optional atom applied to the changeset's `:action` attribute. Useful for forms that
    look to a changeset's action to influence form presentation.
  """
  @spec create_user_changeset(
          attrs :: create_user_attrs(),
          opts :: Keyword.t()
        ) :: Ecto.Changeset.t()
  def create_user_changeset(attrs \\ %{}, opts \\ []) do
    opts = Keyword.validate!(opts, action: nil)

    changeset = User.registration_changeset(attrs)

    if opts[:action] do
      Map.put(changeset, :action, opts[:action])
    else
      changeset
    end
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `Wayfinder.Accounts.User.email_changeset/3` for a list of supported options.
  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
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
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `Wayfinder.Accounts.User.password_changeset/3` for a list of supported options.
  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
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

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.
  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
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
end
