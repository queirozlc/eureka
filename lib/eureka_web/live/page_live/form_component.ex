defmodule EurekaWeb.PageLive.FormComponent do
  use EurekaWeb, :live_component
  alias Eureka.{Accounts, Accounts.User}
  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="guest-form"
        class="flex flex-col gap-40 pt-10"
        action={~p"/users/log_in?_action=guest_user/#{@guest_id}"}
        phx-target={@myself}
        phx-trigger-action={@trigger_submit}
        phx-change="validate"
        phx-submit="save"
        method="post"
      >
        <.error :if={@check_errors}>
          Oops, something went wrong! Please check the errors below.
        </.error>

        <div class="flex flex-col gap-12">
          <%!-- renders the @avatar svg if exists --%>
          <%= if @avatar do %>
            <div class="self-center size-32 sm:size-40 shadow-brutalism" id="avatar_container">
              <%= @avatar |> raw() %>
            </div>
          <% end %>

          <div class="flex flex-col mx-auto w-full max-w-[90%]">
            <.input
              field={@form[:nickname]}
              type="text"
              label="What's your nickname?"
              placeholder="Your display name in match"
              class="!rounded-full bg-white !outline-none !border-2 !border-black shadow-brutalism font-mono font-medium h-12 focus:ring-offset-0 focus:ring-0 focus:border-current"
              required
            />
          </div>
        </div>

        <div class="flex flex-col items-center space-y-2">
          <button
            class="py-3 font-mono font-medium !bg-contrast-yellow border-2 border-black h-12 flex items-center justify-center hover:bg-brand-yellow !text-black active:!text-black w-full max-w-sm text-lg transition-shadow duration-200 hover:shadow-brutalism gap-2"
            type="submit"
          >
            <%= @submit_label %>
          </button>

          <div class="flex items-center gap-2 w-[50%]">
            <span class="flex-1 border-t-2 border-gray-200" />
            <span class="text-sm font-mono leading-6 text-zinc-900 font-semibold">
              or
            </span>
            <span class="flex-1 border-t-2 border-gray-200" />
          </div>

          <.link
            class="text-lg font-mono leading-6 text-zinc-900 font-semibold hover:text-zinc-700 hover:underline underline-offset-2"
            navigate={~p"/users/log_in"}
          >
            Log in
          </.link>
        </div>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_guest_user(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_guest(user_params) do
      {:ok, user} ->
        changeset = Accounts.change_guest_user(user)

        {:noreply,
         socket
         |> assign_form(changeset)
         |> assign(guest_id: user.id)
         |> assign(trigger_submit: true)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  @impl true
  def mount(socket) do
    changeset = Accounts.change_guest_user(%User{})

    socket =
      socket
      |> assign_form(changeset)
      |> assign(trigger_submit: false, check_errors: false)
      |> assign(guest_id: "")

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
