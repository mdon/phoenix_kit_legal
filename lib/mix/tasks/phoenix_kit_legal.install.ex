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

  @css_source_directive ~s(@source "../../deps/phoenix_kit_legal";)
  @css_source_pattern ~r/@source\s+["'][^"']*phoenix_kit_legal["']/

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

  # Insert after the last `plug Plug.Static` block in the file.
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

  # Returns the byte position AFTER the last `plug Plug.Static` block ends.
  # Scans forward from the plug line while lines are indented continuation lines
  # (not starting a new `plug` or `end` keyword).
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
        end_idx = find_block_end(lines, last_idx)
        # Position after the last line of the block (after its newline)
        pos = line_start_position(content, end_idx + 1)
        {:ok, pos}
    end
  end

  # Scans forward from start_idx while lines look like continuation lines
  # (indented and not starting a new top-level keyword).
  defp find_block_end(lines, start_idx) do
    total = length(lines)
    start_line = Enum.at(lines, start_idx)
    base_indent = leading_spaces(start_line)

    Enum.reduce_while((start_idx + 1)..(total - 1), start_idx, fn i, last ->
      line = Enum.at(lines, i)
      cond do
        # blank line — block ended
        String.trim(line) == "" -> {:halt, last}
        # less or equal indentation — new statement at same/outer level
        leading_spaces(line) <= base_indent -> {:halt, last}
        # continuation line
        true -> {:cont, i}
      end
    end)
  end

  defp leading_spaces(line) do
    line
    |> String.graphemes()
    |> Enum.take_while(&(&1 == " "))
    |> length()
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

  @doc false
  def insert_css_source(content) do
    if String.match?(content, @css_source_pattern) do
      content
    else
      insert_after_last_source(content)
    end
  end

  defp insert_after_last_source(content) do
    lines = String.split(content, "\n")

    last_source =
      lines
      |> Enum.with_index()
      |> Enum.reverse()
      |> Enum.find(fn {line, _i} -> String.match?(line, ~r/^@source\s+/) end)

    case last_source do
      {_line, idx} ->
        {before, rest} = Enum.split(lines, idx + 1)
        Enum.join(before ++ [@css_source_directive] ++ rest, "\n")

      nil ->
        last_import =
          lines
          |> Enum.with_index()
          |> Enum.reverse()
          |> Enum.find(fn {line, _i} -> String.match?(line, ~r/^@import\s+/) end)

        case last_import do
          {_line, idx} ->
            {before, rest} = Enum.split(lines, idx + 1)
            Enum.join(before ++ [@css_source_directive] ++ rest, "\n")

          nil ->
            @css_source_directive <> "\n" <> content
        end
    end
  end

  defp patch_css do
    if File.exists?("assets/tailwind.config.js") do
      Mix.shell().info("  ⚠  Tailwind v3 detected (tailwind.config.js found).")
      Mix.shell().info("     Add manually to tailwind.config.js content array:")
      Mix.shell().info(~s(     "../deps/phoenix_kit_legal/**/*.ex"))
    else
      css_paths = ["assets/css/app.css", "priv/static/assets/app.css", "assets/app.css"]

      case Enum.find(css_paths, &File.exists?/1) do
        nil ->
          Mix.shell().info("  ⚠  Could not find app.css — add @source manually.")
        path ->
          content = File.read!(path)
          updated = insert_css_source(content)

          if updated == content do
            Mix.shell().info("  ✓ app.css already has @source for phoenix_kit_legal")
          else
            File.write!(path, updated)
            Mix.shell().info("  ✓ Added @source directive to #{path}")
          end
      end
    end
  end

  @doc false
  def copy_js_to_vendor do
    src = Application.app_dir(:phoenix_kit_legal, "priv/static/assets/phoenix_kit_consent.js")
    dest_dir = "assets/vendor"
    dest = Path.join(dest_dir, "phoenix_kit_consent.js")

    if File.exists?(dest) do
      Mix.shell().info("  [skip] #{dest} already exists.")
    else
      File.mkdir_p!(dest_dir)
      File.copy!(src, dest)
      Mix.shell().info("  [ok]   Copied phoenix_kit_consent.js to #{dest}.")
    end
  end

  defp print_next_steps do
    Mix.shell().info("""

    ── Next steps ────────────────────────────────────────────────────────────────

    1. Run the migration:

         mix ecto.migrate

       (or copy priv/migrations/add_phoenix_kit_consent_logs.exs into your
        app's priv/repo/migrations/ and rename MyApp.Repo accordingly)

    2. Add the JS hook in assets/js/app.js:

         import PhoenixKitConsent from "../vendor/phoenix_kit_consent";
         let liveSocket = new LiveSocket("/live", Socket, {
           hooks: { PhoenixKitConsent, ...Hooks }
         });

    3. Add the router scope in your router.ex:

         use PhoenixKitLegal.Router
         # or manually:
         scope "/legal" do
           pipe_through :browser
           live "/consent", PhoenixKitLegal.ConsentLive
         end

    4. (Optional) Configure in config/config.exs:

         config :phoenix_kit_legal,
           consent_version: "1.0",
           cookie_name: "__consent"

    ──────────────────────────────────────────────────────────────────────────────
    """)
  end
end
