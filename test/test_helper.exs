ExUnit.start()

# Start the PhoenixKit settings cache so Settings-backed helpers (e.g.
# Legal.hide_for_authenticated?/0) resolve cleanly without a full Ecto/Repo
# setup. Tests seed specific values via
# `PhoenixKit.Cache.put(:settings, key, value)`.
case PhoenixKit.Cache.Registry.start_link() do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
end

case PhoenixKit.Cache.start_link(name: :settings) do
  {:ok, _pid} -> :ok
  {:error, {:already_started, _pid}} -> :ok
end
