defmodule WayfinderWeb.UserLive.Registration do
  @moduledoc """
  A live view that presents a user registration form.
  """

  use WayfinderWeb, :live_view

  alias Wayfinder.Accounts

  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    # A currently authenticated user should not be allowed to register.
    # Redirect authenticated users away from the registration form.
    {:ok, redirect(socket, to: WayfinderWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.user_registration_changeset()

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    %{"email" => email, "password" => password} = user_params

    case Accounts.register_user(email, password) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "An email was sent to #{user.email}, please access it to confirm your account."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    %{"email" => email, "password" => password} = user_params

    changeset = Accounts.user_registration_changeset(email, password, action: :validate)
    {:noreply, assign_form(socket, changeset)}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            Register for an account
            <:subtitle>
              Already registered?
              <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
                Log in
              </.link>
              to your account now.
            </:subtitle>
          </.header>
        </div>

        <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            required
            phx-mounted={JS.focus()}
          />

          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            autocomplete="new-password"
          />

          <.input
            field={@form[:password_confirmation]}
            type="password"
            label="Confirm password"
            autocomplete="new-password"
            required
          />

          <.button phx-disable-with="Creating account..." class="btn btn-primary w-full">
            Create an account
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end
end
