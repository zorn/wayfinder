defmodule Wayfinder.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Wayfinder.Accounts` context.
  """

  import Ecto.Query

  alias Wayfinder.Accounts
  alias Wayfinder.Accounts.Scope
  alias Wayfinder.Accounts.User

  @spec unique_user_email() :: String.t()
  def unique_user_email, do: "user#{System.unique_integer()}@example.com"

  @spec valid_user_password() :: String.t()
  def valid_user_password, do: "hello world!"

  @spec valid_user_attributes(attrs :: map()) :: map()
  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: "some-good-test-password",
      password_confirmation: "some-good-test-password"
    })
  end

  @spec unconfirmed_user_fixture(attrs :: map()) :: User.t()
  def unconfirmed_user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Accounts.cast_create_user_attrs()
      |> Accounts.create_user()

    user
  end

  # FIXME: Feels odd for the fixture to have named fixtures for `unconfirmed`
  # and then this -- with no changes. Should clean up.
  @spec user_fixture(attrs :: map()) :: User.t()
  def user_fixture(attrs \\ %{}) do
    unconfirmed_user_fixture(attrs)
  end

  @spec user_scope_fixture() :: Scope.t()
  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  @spec user_scope_fixture(User.t()) :: Scope.t()
  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  @spec set_password(User.t()) :: User.t()
  def set_password(user) do
    new_password = valid_user_password()

    {:ok, {user, _expired_tokens}} =
      Accounts.update_user_password(user, %{
        password: new_password,
        password_confirmation: new_password
      })

    user
  end

  @spec extract_user_token(fun()) :: String.t()
  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  @spec override_token_authenticated_at(
          token :: String.t(),
          authenticated_at :: DateTime.t()
        ) :: :ok
  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    Wayfinder.Repo.update_all(
      from(t in Accounts.UserToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  @spec generate_user_magic_link_token(User.t()) ::
          {encoded_token :: String.t(), token :: String.t()}
  def generate_user_magic_link_token(user) do
    {encoded_token, user_token} = Accounts.UserToken.build_email_token(user, "login")
    Wayfinder.Repo.insert!(user_token)
    {encoded_token, user_token.token}
  end

  @spec offset_user_token(
          token :: String.t(),
          amount_to_add :: integer(),
          unit :: :second | :minute | :hour | :day
        ) :: :ok
  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    Wayfinder.Repo.update_all(
      from(ut in Accounts.UserToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end
end
