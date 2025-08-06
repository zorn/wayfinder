defmodule WayfinderWeb.UserLive.Login do
  use WayfinderWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-4">
        <div class="text-center">
          <.header>
            <p>Log in</p>
            <:subtitle>
              <%= if @current_scope do %>
                You need to reauthenticate to perform sensitive actions on your account.
              <% else %>
                Don't have an account? <.link
                  navigate={~p"/users/register"}
                  class="font-semibold text-brand hover:underline"
                  phx-no-format
                >Sign up</.link> for an account now.
              <% end %>
            </:subtitle>
          </.header>
        </div>

        <.form
          :let={f}
          for={@form}
          id="login_form_password"
          action={~p"/users/log-in"}
          phx-submit="submit_password"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            required
          />
          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            autocomplete="current-password"
          />
          <.input field={@form[:remember_me]} type="checkbox" label="Remember me" autocomplete="off" />
          <.button class="btn btn-primary w-full">
            Log in <span aria-hidden="true">→</span>
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  # FIXME: Remove
  # def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
  #   if user = Accounts.get_user_by_email(email) do
  #     Accounts.deliver_login_instructions(
  #       user,
  #       &url(~p"/users/log-in/#{&1}")
  #     )
  #   end

  #   info =
  #     "If your email is in our system, you will receive instructions for logging in shortly."

  #   {:noreply,
  #    socket
  #    |> put_flash(:info, info)
  #    |> push_navigate(to: ~p"/users/log-in")}
  # end

  defp local_mail_adapter? do
    Application.get_env(:wayfinder, Wayfinder.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
