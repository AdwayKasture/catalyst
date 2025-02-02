defmodule CatalystWeb.Sidebar do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div class="relative">
      <!-- Sidebar -->
      <%= if @current_user  do %>
        <aside class="bg-gray-800 fixed top-0 left-0 z-40 w-64 h-screen transition-transform -translate-x-full sm:translate-x-0 pt-8">
          <nav>
            <.logo_card />
            <.user_card user_name={@current_user.username} />
            <%= for {label, path} <- menu_items() do %>
              <.nav_item path={path} label={label} />
            <% end %>
            <%= if @current_user.role == :admin do %>
              <%= for {label, path} <- admin_items() do %>
                <.nav_item path={path} label={label} />
              <% end %>
            <% end %>
            <.log_out />
          </nav>
        </aside>
      <% else %>
        <aside class="fixed top-0 left-0 z-40 w-64 h-screen transition-transform -translate-x-full sm:translate-x-0 pt-8">
          <.logo_card />
        </aside>
      <% end %>
    </div>
    """
  end

  def nav_item(assigns) do
    ~H"""
    <.link
      navigate={@path}
      class="block py-2.5 px-4 rounded transition duration-200 hover:bg-gray-700"
    >
      <%= @label %>
    </.link>
    """
  end

  def user_card(assigns) do
    ~H"""
    <div class="block py-2.5 px-4  transition duration-200  border-t border-b border-gray-600">
      <%= @user_name %>
    </div>
    """
  end

  def logo_card(assigns) do
    ~H"""
    <a href="/" class="text-3xl font-bold text-blue-400 px-8 ">Catalyst</a>
    """
  end

  def log_out(assigns) do
    ~H"""
    <.link
      href="/users/log_out"
      method="delete"
      class="block py-2.5 px-4 rounded transition duration-200 hover:bg-gray-700"
    >
      Log out
    </.link>
    """
  end

  defp menu_items do
    [
      {"Home", "/dashboard"},
      {"Transactions", "/history"},
      {"Settings", "/users/settings"}
    ]
  end

  defp admin_items do
    [
      {"Data", "/admin"}
    ]
  end
end
