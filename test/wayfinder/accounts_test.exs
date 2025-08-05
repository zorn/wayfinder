defmodule Wayfinder.AccountsTest do
  use Wayfinder.DataCase, async: true

  doctest Wayfinder.Accounts, import: true

  import Wayfinder.AccountsFixtures

  alias Wayfinder.Accounts
  alias Wayfinder.Accounts.User
  alias Wayfinder.Accounts.UserToken

  describe "cast_create_user_attrs/1" do
    # Logic verified through `doctest` examples.
  end

  describe "cast_update_user_email_attrs/1" do
    # Logic verified through `doctest` examples.
  end

  describe "create_user/1" do
    test "requires email to be set" do
      {:error, changeset} = Accounts.create_user(%{})
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email when given" do
      {:error, changeset} = Accounts.create_user(%{email: "not valid"})
      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email" do
      too_long = String.duplicate("a", 161)
      {:error, changeset} = Accounts.create_user(%{email: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email contains an @ sign" do
      {:error, changeset} = Accounts.create_user(%{email: "nope"})
      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates email does not contain spaces" do
      {:error, changeset} = Accounts.create_user(%{email: "foo@example.com foo"})
      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.create_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.create_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "requires password to be set" do
      {:error, changeset} = Accounts.create_user(%{})
      assert %{password: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates maximum values for password" do
      too_long = String.duplicate("a", 73)
      {:error, changeset} = Accounts.create_user(%{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates minimum values for password" do
      too_short = String.duplicate("a", 11)
      {:error, changeset} = Accounts.create_user(%{password: too_short})
      assert "should be at least 12 character(s)" in errors_on(changeset).password
    end

    test "validates password confirmation" do
      {:error, changeset} =
        Accounts.create_user(%{
          password: "super secret password",
          password_confirmation: "not super secret password"
        })

      assert %{password_confirmation: ["does not match password"]} = errors_on(changeset)
    end
  end

  describe "create_user_changeset/1" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.create_user_changeset()
      assert Enum.sort(changeset.required) == [:email, :password]
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    test "sends token through notification" do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "generate_user_session_token/1" do
    test "generates a token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"
      assert user_token.authenticated_at != nil

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end

    test "duplicates the authenticated_at of given user in new token" do
      user = user_fixture()
      user = %{user | authenticated_at: DateTime.add(DateTime.utc_now(:second), -3600)}
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.authenticated_at == user.authenticated_at
      assert DateTime.compare(user_token.inserted_at, user.authenticated_at) == :gt
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!("11111111-1111-1111-1111-111111111111")
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture() |> set_password()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture() |> set_password()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert {session_user, token_inserted_at} = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
      assert session_user.authenticated_at != nil
      assert token_inserted_at != nil
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: dt, authenticated_at: dt])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "recently_authenticated?/2" do
    test "validates the `authenticated_at` time" do
      now = DateTime.utc_now()

      assert Accounts.recently_authenticated?(%User{authenticated_at: DateTime.utc_now()})

      assert Accounts.recently_authenticated?(%User{
               authenticated_at: DateTime.add(now, -19, :minute)
             })

      refute Accounts.recently_authenticated?(%User{
               authenticated_at: DateTime.add(now, -21, :minute)
             })

      # minute override
      refute Accounts.recently_authenticated?(
               %User{authenticated_at: DateTime.add(now, -11, :minute)},
               -10
             )

      # not authenticated
      refute Accounts.recently_authenticated?(%User{})
    end
  end

  describe "update_user_email/2" do
    setup do
      user = unconfirmed_user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert {:ok, %{email: ^email}} = Accounts.update_user_email(user, token)
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      # This test is checking a race condition protection mechanism in the email
      # update functionality.
      #
      # The test simulates a situation where:
      # 1. A user requests an email change (e.g., from old@example.com to
      #    new@example.com)
      # 2. A token is generated and sent to the user's email
      # 3. Before the user clicks the token link, someone else (or the user
      #    themselves) changes the user's email to a different address
      #    (current@example.com)
      # 4. The user then tries to use the original token to complete the email
      #    change

      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert Accounts.update_user_email(user, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "update_user_email_changeset/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.update_user_email_changeset(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "update_user_password/2" do
    test "validates password" do
      user = user_fixture()

      {:error, changeset} =
        Accounts.update_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security" do
      user = user_fixture()

      too_long = String.duplicate("a", 73)

      {:error, changeset} =
        Accounts.update_user_password(user, %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password" do
      user = user_fixture()

      {:ok, {user, expired_tokens}} =
        Accounts.update_user_password(user, %{
          password: "new valid password",
          password_confirmation: "new valid password"
        })

      assert expired_tokens == []
      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user" do
      user = user_fixture()

      _ = Accounts.generate_user_session_token(user)

      {:ok, {_, _}} =
        Accounts.update_user_password(user, %{
          password: "new valid password",
          password_confirmation: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "update_user_password_changeset/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.update_user_password_changeset(%User{})
      assert changeset.required == [:password]
    end

    test "updates the hashed password value" do
      changeset =
        Accounts.update_user_password_changeset(
          %User{},
          %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        )

      assert changeset.valid?
      assert is_nil(get_change(changeset, :password))
      assert !is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "Wayfinder.Accounts.User" do
    # Generally we try to align test modules functions with the context module
    # functions, but this is a kind of special case, and since we don't expect
    # call sites to reach into the `Wayfinder.Accounts.User` module, we are
    # testing this redact logic here.

    test "`inspect/2` does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
