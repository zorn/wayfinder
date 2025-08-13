defmodule WayfinderWeb.UserRegistrationController do
  use WayfinderWeb, :controller

  alias Wayfinder.Accounts
  alias Wayfinder.Accounts.User
  alias WayfinderWeb.UserAuth

  @spec new(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def new(%{assigns: %{current_scope: %{user: user}}} = conn, _params)
      when is_struct(user, User) do
    conn
    |> put_flash(:error, "You can not register a new account while logged in.")
    |> redirect(to: WayfinderWeb.UserAuth.signed_in_path(conn))
  end

  def new(conn, _params) do
    changeset = Accounts.create_user_changeset()
    form = Phoenix.Component.to_form(changeset)
    render(conn, :new, form: form)
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"user" => user_params}) do
    attrs = Accounts.cast_create_user_attrs(user_params)

    case Accounts.create_user(attrs) do
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
