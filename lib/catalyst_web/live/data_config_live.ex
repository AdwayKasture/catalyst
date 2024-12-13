defmodule CatalystWeb.DataConfigLive do
  require Logger
  alias Catalyst.DateTime.MarketHoliday
  alias Catalyst.MarketData.BhavCopy
  use CatalystWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:upload_error_md, nil)
     |> assign(:processing_md, false)
     |> assign(:upload_status_md, nil)
     |> assign(:dragging_md, false)
     |> assign(:upload_error_mh, nil)
     |> assign(:processing_mh, false)
     |> assign(:upload_status_mh, nil)
     |> assign(:dragging_mh, false)
     |> allow_upload(:market_data,
       accept: ~w(.csv .zip),
       max_entries: 1,
       # 25MB
       max_file_size: 25_000_000,
       auto_upload: true
     )
     |> allow_upload(:holiday_data,
       accept: ~w(.csv .txt),
       auto_upload: true
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-xl mx-auto mt-8">
      <div class="flex flex-col space-y-4">
        <.market_data
          dragging={@dragging_md}
          data={@uploads.market_data}
          upload_error={@upload_error_md}
          processing={@processing_md}
          upload_status={@upload_status_md}
        />
        <.market_holiday
          dragging={@dragging_mh}
          data={@uploads.holiday_data}
          upload_error={@upload_error_mh}
          processing={@processing_mh}
          upload_status={@upload_status_mh}
        />
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("dragenter_md", _params, socket) do
    {:noreply, assign(socket, :dragging_md, true)}
  end

  @impl Phoenix.LiveView
  def handle_event("dragleave_md", _params, socket) do
    {:noreply, assign(socket, :dragging_md, false)}
  end

  @impl Phoenix.LiveView
  def handle_event("dropped_md", _params, socket) do
    {:noreply, assign(socket, :dragging_md, false)}
  end

  @impl Phoenix.LiveView
  def handle_event("dragenter_mh", _params, socket) do
    {:noreply, assign(socket, :dragging_mh, true)}
  end

  @impl Phoenix.LiveView
  def handle_event("dragleave_mh", _params, socket) do
    {:noreply, assign(socket, :dragging_mh, false)}
  end

  @impl Phoenix.LiveView
  def handle_event("dropped_mh", _params, socket) do
    {:noreply, assign(socket, :dragging_mh, false)}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("save_md", _params, socket) do
    if socket.assigns.processing_md do
      {:noreply, socket}
    else
      socket = assign(socket, processing_md: true, upload_error_md: nil)

      consume_uploaded_entries(socket, :market_data, fn %{path: path}, entry ->
        dest = Path.join([:code.priv_dir(:catalyst), "static", "uploads", Path.basename(path)])

        # You will need to create `priv/static/uploads` for `File.cp!/2` to work.
        File.cp!(path, dest)

        Task.Supervisor.async_nolink(Catalyst.TaskSupervisor, fn ->
          BhavCopy.fetch_data_from_file(dest, Path.extname(entry.client_name))
        end)

        {:ok, :started_processing}
      end)

      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("save_mh", _params, socket) do
    if socket.assigns.processing_mh do
      {:noreply, socket}
    else
      socket = assign(socket, processing_mh: true, upload_error_mh: nil)

      consume_uploaded_entries(socket, :holiday_data, fn %{path: path}, _entry ->
        dest = Path.join([:code.priv_dir(:catalyst), "static", "uploads", Path.basename(path)])

        # You will need to create `priv/static/uploads` for `File.cp!/2` to work.
        File.cp!(path, dest)

        Task.Supervisor.async_nolink(Catalyst.TaskSupervisor, fn ->
          MarketHoliday.ingest_holidays(dest)
        end)

        {:ok, :started_processing}
      end)

      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload-md", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :market_data, ref)}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload-mh", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :holiday_data, ref)}
  end

  @impl true
  def handle_info({ref, {:ok, :holidays_loaded}}, socket) do
    Process.demonitor(ref, [:flush])

    {:noreply,
     socket
     |> assign(processing_mh: false)
     |> assign(upload_status_mh: "Successfully processed file import")}
  end

  @impl true
  def handle_info({ref, {:ok, :market_data_loaded}}, socket) do
    Process.demonitor(ref, [:flush])

    {:noreply,
     socket
     |> assign(processing_md: false)
     |> assign(upload_status_md: "Successfully processed file import")}
  end

  @impl true
  def handle_info({:DOWN, ref, _, _, _}, socket) do
    Process.demonitor(ref, [:flush])
    Logger.error("failed to process file")

    {:noreply,
     socket
     |> assign(processing_md: false)
     |> assign(processing_mh: false)
     |> assign(upload_status_md: nil)
     |> assign(upload_status_mh: nil)
     |> assign(upload_error_md: "File upload failed please check logs")
     |> assign(upload_error_mh: "File upload failed please check logs")}
  end

  def market_data(assigns) do
    ~H"""
    <form id="upload-form" phx-submit="save_md" phx-change="validate">
      <div class="flex flex-col space-y-4">
        <div
          class={[
            "border-2 border-dashed rounded-lg p-6",
            "transition-colors duration-200",
            @dragging && "border-primary-400 bg-primary-50",
            "hover:border-primary-400"
          ]}
          phx-drop-target={@data.ref}
          phx-dragenter="dragenter_md"
          phx-dragleave="dragleave_md"
          phx-drop="dropped_md"
        >
          <div class="flex flex-col items-center justify-center space-y-2">
            <div class="text-center">
              <.label for={@data.ref}>Upload Market Data CSV or ZIP</.label>
              <div class="mt-2 text-sm text-gray-500">
                Drag and drop or click to select a CSV file
              </div>
            </div>

            <div class="relative">
              <.live_file_input upload={@data} class="sr-only" />
              <.button type="button" phx-click={JS.dispatch("click", to: "##{@data.ref}")}>
                Select File
              </.button>
            </div>
          </div>

          <%= for entry <- @data.entries do %>
            <div class="mt-4">
              <div class="flex items-center gap-4">
                <div class="flex-1">
                  <div class="text-sm font-medium"><%= entry.client_name %></div>
                  <div class="mt-1 h-2 rounded-full bg-gray-200">
                    <div class="h-2 rounded-full bg-primary-500" style={"width: #{entry.progress}%"}>
                    </div>
                  </div>
                </div>
                <button
                  type="button"
                  class="text-red-500 hover:text-red-700"
                  phx-click="cancel-upload-md"
                  phx-value-ref={entry.ref}
                >
                  &times;
                </button>
              </div>

              <%= for err <- upload_errors(@data, entry) do %>
                <div class="mt-1 text-sm text-red-500"><%= error_to_string(err) %></div>
              <% end %>
            </div>
          <% end %>
        </div>

        <.upload_statues
          upload_error={@upload_error}
          processing={@processing}
          upload_status={@upload_status}
        />

        <div class="flex justify-end">
          <.button type="submit" disabled={@processing || Enum.empty?(@data.entries)}>
            Upload
          </.button>
        </div>
      </div>
    </form>
    """
  end

  def market_holiday(assigns) do
    ~H"""
    <form id="holiday-form" phx-submit="save_mh" phx-change="validate">
      <div class="flex flex-col space-y-4">
        <div
          class={[
            "border-2 border-dashed rounded-lg p-6",
            "transition-colors duration-200",
            @dragging && "border-primary-400 bg-primary-50",
            "hover:border-primary-400"
          ]}
          phx-drop-target={@data.ref}
          phx-dragenter="dragenter_mh"
          phx-dragleave="dragleave_mh"
          phx-drop="dropped_mh"
        >
          <div class="flex flex-col items-center justify-center space-y-2">
            <div class="text-center">
              <.label for={@data.ref}>Upload Market Holidays CSV</.label>
              <div class="mt-2 text-sm text-gray-500">
                Drag and drop or click to select a CSV file
              </div>
            </div>

            <div class="relative">
              <.live_file_input upload={@data} class="sr-only" />
              <.button type="button" phx-click={JS.dispatch("click", to: "##{@data.ref}")}>
                Select File
              </.button>
            </div>
          </div>

          <%= for entry <- @data.entries do %>
            <div class="mt-4">
              <div class="flex items-center gap-4">
                <div class="flex-1">
                  <div class="text-sm font-medium"><%= entry.client_name %></div>
                  <div class="mt-1 h-2 rounded-full bg-gray-200">
                    <div class="h-2 rounded-full bg-primary-500" style={"width: #{entry.progress}%"}>
                    </div>
                  </div>
                </div>
                <button
                  type="button"
                  class="text-red-500 hover:text-red-700"
                  phx-click="cancel-upload-mh"
                  phx-value-ref={entry.ref}
                >
                  &times;
                </button>
              </div>

              <%= for err <- upload_errors(@data, entry) do %>
                <div class="mt-1 text-sm text-red-500"><%= error_to_string(err) %></div>
              <% end %>
            </div>
          <% end %>
        </div>
        <.upload_statues
          upload_error={@upload_error}
          processing={@processing}
          upload_status={@upload_status}
        />

        <div class="flex justify-end">
          <.button type="submit" disabled={@processing || Enum.empty?(@data.entries)}>
            Upload
          </.button>
        </div>
      </div>
    </form>
    """
  end

  def upload_statues(assigns) do
    ~H"""
    <%= if @upload_error do %>
      <div class="text-sm text-red-500">
        <%= @upload_error %>
      </div>
    <% end %>

    <%= if @processing do %>
      <div class="flex items-center justify-center space-x-2">
        <div class="animate-spin rounded-full h-4 w-4 border-2 border-primary-500 border-t-transparent">
        </div>
        <span class="text-sm">Processing file...</span>
      </div>
    <% end %>

    <%= if @upload_status do %>
      <div class="text-sm text-green-500">
        <%= @upload_status %>
      </div>
    <% end %>
    """
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:not_accepted), do: "Invalid file type. Please upload a CSV or ZIP file"
  defp error_to_string(:too_many_files), do: "Only one file can be uploaded at a time"
  defp error_to_string(error) when is_binary(error), do: error
  defp error_to_string(_), do: "An unknown error occurred"
end
