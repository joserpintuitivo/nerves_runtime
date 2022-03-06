defmodule Nerves.Runtime.Kernel.UEvent do
  use GenServer
  require Logger

  @moduledoc """
  GenServer that captures Linux uevent messages and passes them up to Elixir.
  """

  @type state() :: %{port: port(), use_system_registry: boolean()}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    autoload = Keyword.get(opts, :autoload_modules, true)
    use_system_registry = Keyword.get(opts, :use_system_registry, true)

    executable = :code.priv_dir(:nerves_runtime) ++ '/nerves_runtime'

    args = if autoload, do: ["modprobe"], else: []

    port =
      Port.open({:spawn_executable, executable}, [
        {:arg0, "uevent"},
        {:args, args},
        {:packet, 2},
        :use_stdio,
        :binary,
        :exit_status
      ])

    {:ok, %{port: port, use_system_registry: use_system_registry}}
  end

  @impl GenServer
  def handle_info({port, {:data, message}}, %{port: port} = s) do
    {action, scope_no_state, kvmap} = :erlang.binary_to_term(message)
    _ = registry(action, [:state | scope_no_state], kvmap, s)
    {:noreply, s}
  end

  def registry("add", scope, kvmap, s) do
    # Logger.debug("uevent add: #{inspect(scope)}")

    if s.use_system_registry do
      if subsystem = Map.get(kvmap, "subsystem") do
        _ =
          SystemRegistry.update_in(subsystem_scope(subsystem), fn v ->
            v = if is_nil(v), do: [], else: v
            [scope | v]
          end)

        :ok
      end

      SystemRegistry.update(scope, kvmap)
    end
  end

  def registry("remove", scope, kvmap, %{use_system_registry: true}) do
    # Logger.debug("uevent remove: #{inspect(scope)}")
    _ = SystemRegistry.delete(scope)

    if subsystem = Map.get(kvmap, "subsystem") do
      SystemRegistry.update_in(subsystem_scope(subsystem), fn v ->
        v = if is_nil(v), do: [], else: v
        {_, scopes} = Enum.split_with(v, fn v -> v == scope end)
        scopes
      end)
    end
  end

  def registry("move", new_scope, %{"devpath_old" => devpath_old}, %{use_system_registry: true}) do
    # Logger.debug("uevent move: #{inspect(scope(devpath_old))} -> #{inspect(new_scope)}")
    SystemRegistry.move(scope(devpath_old), new_scope)
  end

  def registry(_action, _scope, _kvmap, _s) do
    # Logger.debug("uevent unhandled: #{inspect(action)}")
  end

  defp scope("/" <> devpath) do
    scope(devpath)
  end

  defp scope(devpath) do
    [:state | String.split(devpath, "/")]
  end

  defp subsystem_scope(subsystem) do
    [:state, "subsystems", subsystem]
  end
end
