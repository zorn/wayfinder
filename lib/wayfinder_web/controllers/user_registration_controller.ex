defmodule WayfinderWeb.UserRegistrationController do
  use WayfinderWeb, :controller

  alias Wayfinder.Accounts
  alias WayfinderWeb.UserAuth

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(%{assigns: %{current_scope: %{user: user}}} = conn, _params) when not is_nil(user) do
    conn
    |> put_flash(:error, "You can not register a new account while logged in.")
    |> redirect(to: WayfinderWeb.UserAuth.signed_in_path(conn))
  end

  def new(conn, _params) do
    changeset = Accounts.user_registration_changeset()
    form = Phoenix.Component.to_form(changeset)
    render(conn, :new, form: form)
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"user" => user_params}) do
    %{
      "email" => email,
      "password" => password,
      "password_confirmation" => password_confirmation
    } = user_params

    case Accounts.register_user(email, password, password_confirmation) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> UserAuth.log_in_user(user, user_params)

      {:error, %Ecto.Changeset{} = changeset} ->
        form = Phoenix.Component.to_form(changeset)
        render(conn, :new, form: form)
    end
  end
end
