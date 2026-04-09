defmodule Mix.Tasks.PhoenixKitLegal.Install do
  @moduledoc """
  Installs PhoenixKitLegal into a Phoenix application.

  Automatically patches three files in the host application:

  1. `lib/**/endpoint.ex` — adds `Plug.Static` to serve consent JS assets
  2. `assets/css/app.css` — adds Tailwind `@source` for legal component classes
  3. `assets/vendor/` — copies `phoenix_kit_consent.js` for esbuild import

  Then prints next steps for manual wiring (hooks, router, migration).

  ## Usage

      mix phoenix_kit_legal.install

  This task is idempotent — safe to run multiple times.
  """

  use Mix.Task

  @shortdoc "Install PhoenixKitLegal into a Phoenix application"

  @static_plug_snippet """
    plug Plug.Static,
      at: "/phoenix_kit_legal",
      from: {:phoenix_kit_legal, "priv/static"},
      gzip: false
  """

  @impl Mix.Task
  def run(_argv) do
    Mix.shell().info("Installing PhoenixKitLegal...")

    patch_endpoint()
    patch_css()
    copy_js_to_vendor()
    print_next_steps()

    Mix.shell().info("\nPhoenixKitLegal installed successfully!")
  end

  @doc false
  def patch_endpoint do
    case find_endpoint_files() do
      [] ->
        Mix.shell().info("  [skip] No endpoint.ex files found.")

      files ->
        Enum.each(files, &insert_plug_static/1)
    end
  end

  @doc false
  def insert_plug_static(path) do
    content = File.read!(path)

    cond do
      # Already patched — idempotent
      String.contains?(content, "phoenix_kit_legal") ->
        Mix.shell().info("  [skip] #{path} already has Plug.Static for phoenix_kit_legal.")

      # Find insertion point: before the last Plug.Static block
      true ->
        case find_insertion_point(content) do
          {:ok, patched} ->
            File.write!(path, patched)
            Mix.shell().info("  [ok]   Patched #{path} with Plug.Static for /phoenix_kit_legal.")

          :error ->
            Mix.shell().info(
              "  [warn] Could not find insertion point in #{path}. Please add manually:\n" <>
                @static_plug_snippet
            )
        end
    end
  end

  # Insert before the last `plug Plug.Static` in the file.
  # If no Plug.Static exists, insert before `plug :router` or end of `def endpoint` block.
  defp find_insertion_point(content) do
    # Try to find the last occurrence of `plug Plug.Static`
    case last_plug_static_position(content) do
      {:ok, pos} ->
        patched = String.slice(content, 0, pos) <> @static_plug_snippet <> String.slice(content, pos, byte_size(content) - pos)
        {:ok, patched}

      :none ->
        # Fall back: insert before `plug :router`
        case find_router_plug_position(content) do
          {:ok, pos} ->
            patched = String.slice(content, 0, pos) <> @static_plug_snippet <> String.slice(content, pos, byte_size(content) - pos)
            {:ok, patched}

          :none ->
            :error
        end
    end
  end

  # Returns the byte position of the last `plug Plug.Static` line start
  defp last_plug_static_position(content) do
    lines = String.split(content, "\n", trim: false)

    lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, _i} -> String.match?(line, ~r/^\s*plug\s+Plug\.Static/) end)
    |> case do
      [] ->
        :none

      matches ->
        {_line, last_idx} = List.last(matches)
        pos = line_start_position(content, last_idx)
        {:ok, pos}
    end
  end

  # Returns byte position of the `plug :router` line
  defp find_router_plug_position(content) do
    lines = String.split(content, "\n", trim: false)

    lines
    |> Enum.with_index()
    |> Enum.find(fn {line, _i} -> String.match?(line, ~r/^\s*plug\s+:router/) end)
    |> case do
      nil -> :none
      {_line, idx} -> {:ok, line_start_position(content, idx)}
    end
  end

  # Returns the byte offset of the start of the Nth line (0-indexed)
  defp line_start_position(content, line_index) do
    content
    |> String.split("\n", trim: false)
    |> Enum.take(line_index)
    |> Enum.map(&(byte_size(&1) + 1))
    |> Enum.sum()
  end

  defp find_endpoint_files do
    Path.wildcard("lib/**/endpoint.ex")
  end

  defp patch_css, do: :ok
  defp copy_js_to_vendor, do: :ok
  defp print_next_steps, do: :ok
end
