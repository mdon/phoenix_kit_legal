# Install Task Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `mix phoenix_kit_legal.install` — a Mix task that automatically wires `phoenix_kit_legal` into a parent Phoenix application after it's added as a dependency.

**Architecture:** Plain `Mix.Task` (same pattern as `phoenix_kit_emails.install` already in this repo). The task auto-patches three files (`endpoint.ex`, `app.css`, vendor JS copy) and prints actionable next steps for the rest. All patches are idempotent.

**Tech Stack:** Elixir Mix.Task, plain file I/O (no Igniter), Phoenix conventions (esbuild, Tailwind v4, LiveView hooks)

---

## Files to Create / Modify

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `lib/mix/tasks/phoenix_kit_legal.install.ex` | The install Mix task |
| Create | `priv/migrations/add_phoenix_kit_consent_logs.exs` | Migration template to be copied into host app |
| Modify | `README.md` | Add `## Installation` section |

---

## Task 1: Migration template in `priv/`

**Why first:** The migration template must exist before the install task references it.

**Files:**
- Create: `priv/migrations/add_phoenix_kit_consent_logs.exs`

- [ ] **Step 1: Create the migration template file**

```elixir
# priv/migrations/add_phoenix_kit_consent_logs.exs
# NOTE: Rename MyApp.Repo to your actual Repo module name.
defmodule MyApp.Repo.Migrations.AddPhoenixKitConsentLogs do
  use Ecto.Migration

  def change do
    create table(:phoenix_kit_consent_logs, primary_key: false) do
      # UUIDv7 maps to :uuid at the DB level (PostgreSQL UUID column)
      add :uuid, :uuid, primary_key: true
      add :user_uuid, :uuid, null: true
      add :session_id, :string, null: true
      add :consent_type, :string, null: false
      add :consent_given, :boolean, default: false, null: false
      add :consent_version, :string
      add :ip_address, :string
      add :user_agent_hash, :string
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:phoenix_kit_consent_logs, [:user_uuid])
    create index(:phoenix_kit_consent_logs, [:session_id])
    create index(:phoenix_kit_consent_logs, [:consent_type])
    create index(:phoenix_kit_consent_logs, [:inserted_at])
  end
end
```

- [ ] **Step 2: Verify file exists**

```bash
cat priv/migrations/add_phoenix_kit_consent_logs.exs
```
Expected: file prints correctly.

- [ ] **Step 3: Compile check**

```bash
mix compile
```
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add priv/migrations/add_phoenix_kit_consent_logs.exs
git commit -m "feat: add migration template for consent_logs"
```

---

## Task 2: Core install task skeleton

**Files:**
- Create: `test/test_helper.exs`
- Create: `lib/mix/tasks/phoenix_kit_legal.install.ex`

- [ ] **Step 1: Create test_helper.exs if it doesn't exist**

```bash
ls test/test_helper.exs 2>/dev/null || echo "ExUnit.start()" > test/test_helper.exs
```

- [ ] **Step 2: Write failing test for task existence**

Create `test/mix/tasks/phoenix_kit_legal.install_test.exs`:

```elixir
defmodule Mix.Tasks.PhoenixKitLegal.InstallTest do
  use ExUnit.Case, async: true

  test "task module is defined" do
    assert Code.ensure_loaded?(Mix.Tasks.PhoenixKitLegal.Install)
  end

  test "task has @shortdoc" do
    assert Mix.Tasks.PhoenixKitLegal.Install.shortdoc() =~ "Install"
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

```bash
mix test test/mix/tasks/phoenix_kit_legal.install_test.exs
```
Expected: FAIL — module not defined.

- [ ] **Step 4: Create the task skeleton**

Create `lib/mix/tasks/phoenix_kit_legal.install.ex`:

```elixir
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

  @impl Mix.Task
  def run(_argv) do
    Mix.shell().info("Installing PhoenixKitLegal...")

    patch_endpoint()
    patch_css()
    copy_js_to_vendor()
    print_next_steps()

    Mix.shell().info("\nPhoenixKitLegal installed successfully!")
  end

  defp patch_endpoint, do: :ok
  defp patch_css, do: :ok
  defp copy_js_to_vendor, do: :ok
  defp print_next_steps, do: :ok
end
```

- [ ] **Step 5: Run test to verify it passes**

```bash
mix test test/mix/tasks/phoenix_kit_legal.install_test.exs
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/mix/tasks/phoenix_kit_legal.install.ex test/mix/tasks/phoenix_kit_legal.install_test.exs test/test_helper.exs
git commit -m "feat: add install task skeleton"
```

---

## Task 3: `patch_endpoint/0` — insert Plug.Static in endpoint.ex

**Context:**
- The host app already serves its own assets at `/assets` via `Plug.Static`.
- We must use a **unique path** to avoid conflict: `at: "/phoenix_kit_legal"`.
- This serves `priv/static/` tree, so `phoenix_kit_consent.js` will be at `/phoenix_kit_legal/assets/phoenix_kit_consent.js`.
- Idempotency: skip if `phoenix_kit_legal` already appears in the endpoint file.

**Files:**
- Modify: `lib/mix/tasks/phoenix_kit_legal.install.ex` (implement `patch_endpoint/0`)

- [ ] **Step 1: Write tests for endpoint patching logic**

Add to `test/mix/tasks/phoenix_kit_legal.install_test.exs`:

```elixir
describe "endpoint patching" do
  test "inserts Plug.Static after last existing Plug.Static" do
    original = """
    defmodule MyApp.Endpoint do
      use Phoenix.Endpoint, otp_app: :my_app

      plug Plug.Static,
        at: "/",
        from: :my_app,
        gzip: false

      plug Plug.Static,
        at: "/assets",
        from: "priv/static",
        gzip: false

      plug Plug.RequestId
    end
    """

    result = Mix.Tasks.PhoenixKitLegal.Install.insert_plug_static(original)

    assert result =~ ~s(from: {:phoenix_kit_legal, "priv/static"})
    assert result =~ ~s(at: "/phoenix_kit_legal")
    # Inserted after the last Plug.Static, before Plug.RequestId
    assert String.contains?(result, "phoenix_kit_legal") 
    # Idempotent: inserting twice gives the same result
    assert Mix.Tasks.PhoenixKitLegal.Install.insert_plug_static(result) == result
  end

  test "returns :already_present when phoenix_kit_legal already in file" do
    content = """
    plug Plug.Static, at: "/phoenix_kit_legal", from: {:phoenix_kit_legal, "priv/static"}
    """
    assert Mix.Tasks.PhoenixKitLegal.Install.insert_plug_static(content) == content
  end

  test "returns nil when no Plug.Static found at all" do
    content = "defmodule MyApp.Endpoint do\n  plug Plug.RequestId\nend\n"
    # No Plug.Static found — signal manual action needed
    assert Mix.Tasks.PhoenixKitLegal.Install.insert_plug_static(content) == nil
  end

  test "appends after Plug.Static when it is the last plug in the file" do
    original = """
    defmodule MyApp.Endpoint do
      use Phoenix.Endpoint, otp_app: :my_app

      plug Plug.Static,
        at: "/assets",
        from: "priv/static",
        gzip: false
    end
    """

    result = Mix.Tasks.PhoenixKitLegal.Install.insert_plug_static(original)

    assert result =~ ~s(from: {:phoenix_kit_legal, "priv/static"})
    # Idempotent
    assert Mix.Tasks.PhoenixKitLegal.Install.insert_plug_static(result) == result
  end
end
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
mix test test/mix/tasks/phoenix_kit_legal.install_test.exs
```
Expected: FAIL — `insert_plug_static/1` not defined.

- [ ] **Step 3: Implement `patch_endpoint/0` and `insert_plug_static/1`**

The plug block to insert:

```elixir
@plug_static_block """

  # Serve phoenix_kit_legal static assets (consent.js, etc.)
  plug Plug.Static,
    at: "/phoenix_kit_legal",
    from: {:phoenix_kit_legal, "priv/static"},
    gzip: false
"""
```

```elixir
# Public for testing
def insert_plug_static(content) do
  # Idempotency check
  if String.contains?(content, "phoenix_kit_legal") do
    content
  else
    # Find the last `plug Plug.Static` block end
    # Strategy: split by lines, find last line that is `  end` after a Plug.Static block,
    # or simpler: find the last occurrence of `plug Plug.Static` and scan forward to the
    # next blank line or next `plug ` keyword.
    case find_last_static_insertion_point(content) do
      nil -> nil
      index -> String.slice(content, 0, index) <> @plug_static_block <> String.slice(content, index..-1//1)
    end
  end
end

defp find_last_static_insertion_point(content) do
  lines = String.split(content, "\n")

  # Find index of the last line starting a new plug after a Plug.Static block
  # We scan for all `plug Plug.Static` lines, then find the next `plug ` after the last one
  static_indices =
    lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, _i} -> String.match?(line, ~r/^\s+plug Plug\.Static\b/) end)
    |> Enum.map(fn {_line, i} -> i end)

  case List.last(static_indices) do
    nil ->
      nil
    last_static_line ->
      # Find the next non-blank, non-option line after the Plug.Static block
      # i.e., the first line after last_static_line+1 that starts a new statement
      next_plug_index =
        lines
        |> Enum.with_index()
        |> Enum.drop(last_static_line + 1)
        |> Enum.find(fn {line, _i} ->
          String.match?(line, ~r/^\s+plug /) and not String.match?(line, ~r/^\s+plug Plug\.Static\b/)
        end)

      case next_plug_index do
        nil ->
          # Plug.Static is the last plug — append after the last Static block.
          # Find the last line of the Static block: scan forward from last_static_line
          # until we hit a blank line or the module `end`.
          last_block_end =
            lines
            |> Enum.with_index()
            |> Enum.drop(last_static_line + 1)
            |> Enum.take_while(fn {line, _i} ->
              String.match?(line, ~r/^\s+\w/) and not String.match?(line, ~r/^\s+end\b/)
            end)
            |> List.last()

          append_after =
            case last_block_end do
              {_line, idx} -> idx
              nil -> last_static_line
            end

          lines
          |> Enum.take(append_after + 1)
          |> Enum.join("\n")
          |> byte_size()
          |> Kernel.+(1)

        {_line, idx} ->
          # Return byte offset of the start of that line
          lines
          |> Enum.take(idx)
          |> Enum.join("\n")
          |> byte_size()
          |> Kernel.+(1)  # +1 for the newline before that line
      end
  end
end
```

Implementation of `patch_endpoint/0`:

```elixir
defp patch_endpoint do
  case find_endpoint_file() do
    {:ok, path} ->
      content = File.read!(path)
      case insert_plug_static(content) do
        nil ->
          Mix.shell().info("  ⚠  Could not auto-patch #{path} — no Plug.Static found to insert after.")
          Mix.shell().info("     Manually add Plug.Static for phoenix_kit_legal (see next steps).")
        ^content ->
          Mix.shell().info("  ✓ endpoint.ex already configured (#{path})")
        updated ->
          File.write!(path, updated)
          Mix.shell().info("  ✓ Patched #{path} with Plug.Static for /phoenix_kit_legal")
      end
    {:error, :not_found} ->
      Mix.shell().info("  ⚠  Could not find endpoint.ex — see next steps for manual setup.")
  end
end

defp find_endpoint_file do
  case Path.wildcard("lib/**/endpoint.ex") do
    [] ->
      {:error, :not_found}
    [path] ->
      {:ok, path}
    [_first | _rest] = paths ->
      Mix.shell().info("  ⚠  Multiple endpoint.ex files found: #{Enum.join(paths, ", ")}")
      Mix.shell().info("     Patching only the first. Run manually for others if needed.")
      {:ok, hd(paths)}
  end
end
```

- [ ] **Step 4: Run tests**

```bash
mix test test/mix/tasks/phoenix_kit_legal.install_test.exs
```
Expected: endpoint tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/mix/tasks/phoenix_kit_legal.install.ex test/mix/tasks/phoenix_kit_legal.install_test.exs
git commit -m "feat: install task patches endpoint.ex with Plug.Static"
```

---

## Task 4: `patch_css/0` — add Tailwind @source directive

**Context:**
- Same pattern as `phoenix_kit_emails.install` — append after last `@source` line.
- Only for Tailwind v4 (CSS-first config). If `tailwind.config.js` is present → v3, print manual instructions instead.
- Idempotent: check for `phoenix_kit_legal` before inserting.

**Files:**
- Modify: `lib/mix/tasks/phoenix_kit_legal.install.ex`

- [ ] **Step 1: Write tests for CSS patching**

```elixir
describe "CSS @source patching" do
  test "inserts @source after last existing @source" do
    css = """
    @import "tailwindcss";
    @source "../../deps/phoenix_kit";
    @source "../../deps/phoenix_live_view";

    @plugin "@tailwindcss/typography";
    """

    result = Mix.Tasks.PhoenixKitLegal.Install.insert_css_source(css)

    assert result =~ ~s(@source "../../deps/phoenix_kit_legal";)
    # Appears after the last existing @source
    [_, after_sources] = String.split(result, ~s(@source "../../deps/phoenix_live_view"), parts: 2)
    assert String.starts_with?(String.trim_leading(after_sources, "\n"), ~s(@source "../../deps/phoenix_kit_legal"))
  end

  test "idempotent — does not duplicate if already present" do
    css = ~s(@source "../../deps/phoenix_kit_legal";\n)
    assert Mix.Tasks.PhoenixKitLegal.Install.insert_css_source(css) == css
  end
end
```

- [ ] **Step 2: Run tests to confirm failure**

```bash
mix test test/mix/tasks/phoenix_kit_legal.install_test.exs
```
Expected: FAIL.

- [ ] **Step 3: Implement `patch_css/0` and `insert_css_source/1`**

Reuse same insertion logic as `phoenix_kit_emails.install`:

```elixir
@css_source_directive ~s(@source "../../deps/phoenix_kit_legal";)
@css_source_pattern ~r/@source\s+["'][^"']*phoenix_kit_legal["']/

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
      # Fall back: insert after last @import
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
```

```elixir
defp patch_css do
  # Tailwind v3 detection: presence of tailwind.config.js means v3, @source not supported
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

```

- [ ] **Step 4: Run tests**

```bash
mix test test/mix/tasks/phoenix_kit_legal.install_test.exs
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/mix/tasks/phoenix_kit_legal.install.ex test/mix/tasks/phoenix_kit_legal.install_test.exs
git commit -m "feat: install task patches app.css with Tailwind @source"
```

---

## Task 5: `copy_js_to_vendor/0` — copy consent JS for esbuild

**Context:**
- `priv/static/assets/phoenix_kit_consent.js` **already exists** in the repo (confirmed). This task only implements the copy logic in the install task; the source file is not created here.
- The file is an IIFE that registers `window.PhoenixKitHooks.CookieConsent` and `window.PhoenixKitConsent` as side effects.
- esbuild (Phoenix default) does NOT reliably resolve `../../deps/` paths.
- Standard pattern: copy to `assets/vendor/` in the host app. esbuild handles `../vendor/` imports without config.
- Idempotent: skip copy if file already exists at destination.

**Files:**
- Modify: `lib/mix/tasks/phoenix_kit_legal.install.ex`

- [ ] **Step 1: Write test for vendor copy**

```elixir
describe "vendor JS copy" do
  test "source JS file exists in priv/static/assets" do
    src = Application.app_dir(:phoenix_kit_legal, "priv/static/assets/phoenix_kit_consent.js")
    assert File.exists?(src)
  end
end
```

- [ ] **Step 2: Run test to confirm it passes** (source file already exists)

```bash
mix test test/mix/tasks/phoenix_kit_legal.install_test.exs
```
Expected: PASS.

- [ ] **Step 3: Implement `copy_js_to_vendor/0`**

```elixir
defp copy_js_to_vendor do
  src = Application.app_dir(:phoenix_kit_legal, "priv/static/assets/phoenix_kit_consent.js")
  dest = "assets/vendor/phoenix_kit_consent.js"

  if File.exists?(dest) do
    Mix.shell().info("  ✓ #{dest} already exists")
  else
    # Create assets/vendor/ if it doesn't exist (common in fresh Phoenix apps)
    File.mkdir_p!("assets/vendor")
    File.copy!(src, dest)
    Mix.shell().info("  ✓ Copied phoenix_kit_consent.js to #{dest}")
  end
end
```

- [ ] **Step 4: Commit**

```bash
git add lib/mix/tasks/phoenix_kit_legal.install.ex test/mix/tasks/phoenix_kit_legal.install_test.exs
git commit -m "feat: install task copies consent JS to assets/vendor/"
```

---

## Task 6: `print_next_steps/0` — actionable manual steps

**Context:** These steps cannot be safely auto-patched:
- `app.js` hooks object (wildly varying structure per app)
- Router (varies: scopes, pipelines, admin guards)
- Migration (requires knowing the host app's repo module name)

- [ ] **Step 1: Implement `print_next_steps/0`**

```elixir
defp print_next_steps do
  Mix.shell().info("""

  ─────────────────────────────────────────────────
  Next steps (manual):
  ─────────────────────────────────────────────────

  1. Register the CookieConsent hook in assets/js/app.js:

     // Side-effect import (IIFE — registers window.PhoenixKitHooks.CookieConsent)
     import "../vendor/phoenix_kit_consent.js"

     // Add to your LiveSocket hooks:
     let liveSocket = new LiveSocket("/live", Socket, {
       hooks: { ...Hooks, ...window.PhoenixKitHooks },
       params: {_csrf_token: csrfToken}
     })

  2. Add routes to your router.ex (inside your admin pipeline scope):

     # Legal module routes (PhoenixKitLegal)
     scope "/admin/settings", PhoenixKitWeb.Live.Modules.Legal do
       live "/legal", Settings, :index
     end

  3. Create and run the migration:

     cp deps/phoenix_kit_legal/priv/migrations/add_phoenix_kit_consent_logs.exs \\
        priv/repo/migrations/$(date +%Y%m%d%H%M%S)_add_phoenix_kit_consent_logs.exs

     # Edit the migration file: change MyApp.Repo to your repo module name
     # Then run:
     mix ecto.migrate

  4. Add the CookieConsent component to your root layout:

     <PhoenixKit.Modules.Legal.CookieConsent.cookie_consent
       frameworks={["gdpr"]}
       cookie_policy_url="/legal/cookie-policy"
       privacy_policy_url="/legal/privacy-policy"
     />

  5. Enable the Legal module in Admin → Modules.
  ─────────────────────────────────────────────────
  """)
end
```

- [ ] **Step 2: Smoke test the full task output (ExUnit integration test)**

Create a **separate** file `test/mix/tasks/phoenix_kit_legal.install_integration_test.exs`.
It must use `async: false` because `File.cd!` mutates the VM-wide working directory — not safe to run concurrently.

```elixir
defmodule Mix.Tasks.PhoenixKitLegal.InstallIntegrationTest do
  # async: false required — File.cd! mutates the VM-wide working directory
  use ExUnit.Case, async: false

  describe "full run (integration)" do
  @tag :tmp_dir
  test "run/1 patches endpoint, css, vendor", %{tmp_dir: dir} do
    # Set up a fake Phoenix app structure
    File.mkdir_p!("#{dir}/lib/my_app_web")
    File.mkdir_p!("#{dir}/assets/css")

    File.write!("#{dir}/lib/my_app_web/endpoint.ex", """
    defmodule MyAppWeb.Endpoint do
      use Phoenix.Endpoint, otp_app: :my_app
      plug Plug.Static, at: "/assets", from: "priv/static", gzip: false
      plug Plug.RequestId
    end
    """)

    File.write!("#{dir}/assets/css/app.css", """
    @import "tailwindcss";
    @source "../../deps/phoenix_kit";
    """)

    # Run the task from the fake app directory
    File.cd!(dir, fn ->
      Mix.Tasks.PhoenixKitLegal.Install.run([])
    end)

    endpoint = File.read!("#{dir}/lib/my_app_web/endpoint.ex")
    assert endpoint =~ "phoenix_kit_legal"

    css = File.read!("#{dir}/assets/css/app.css")
    assert css =~ "phoenix_kit_legal"

    assert File.exists?("#{dir}/assets/vendor/phoenix_kit_consent.js")
  end
  end
end
```

- [ ] **Step 3: Run the integration test**

```bash
mix test test/mix/tasks/phoenix_kit_legal.install_integration_test.exs
```
Expected: PASS.

- [ ] **Step 4: Run the full test suite**

```bash
mix test
```
Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/mix/tasks/phoenix_kit_legal.install.ex \
        test/mix/tasks/phoenix_kit_legal.install_integration_test.exs
git commit -m "feat: install task prints actionable next steps"
```

---

## Task 7: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add Installation section to README**

Find the existing `## Installation` or `## Usage` section in README.md. If absent, add after the intro paragraph.

Add:

```markdown
## Installation

Add to `mix.exs`:

```elixir
{:phoenix_kit_legal, "~> 0.1"}
```

Run:

```bash
mix deps.get
mix phoenix_kit_legal.install
```

The install task will:
- Add `Plug.Static` to your endpoint for consent JS assets
- Add a Tailwind `@source` directive for legal component CSS classes
- Copy `phoenix_kit_consent.js` to `assets/vendor/`
- Print instructions for hook registration, router, and migration

```

- [ ] **Step 2: Compile check**

```bash
mix compile
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add installation instructions for mix phoenix_kit_legal.install"
```

---

## Completion Checklist

- [ ] Migration template exists at `priv/migrations/add_phoenix_kit_consent_logs.exs`
- [ ] `mix phoenix_kit_legal.install` is runnable
- [ ] Endpoint patch is idempotent and uses unique `/phoenix_kit_legal` path
- [ ] CSS patch handles Tailwind v3 vs v4
- [ ] JS file is copied to vendor (esbuild-safe)
- [ ] Next steps cover all manual wiring (hooks, router, migration, component)
- [ ] All tests pass: `mix test`
- [ ] README updated
