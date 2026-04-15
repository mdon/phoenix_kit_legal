defmodule Mix.Tasks.PhoenixKitLegal.InstallIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  alias Mix.Tasks.PhoenixKitLegal.Install

  # Minimal Phoenix app fixture tree used by all integration tests.
  # Creates: lib/my_app/endpoint.ex, assets/css/app.css
  defp build_fixture(base) do
    endpoint_dir = Path.join(base, "lib/my_app")
    css_dir = Path.join(base, "assets/css")
    File.mkdir_p!(endpoint_dir)
    File.mkdir_p!(css_dir)

    File.write!(Path.join(endpoint_dir, "endpoint.ex"), """
    defmodule MyApp.Endpoint do
      use Phoenix.Endpoint, otp_app: :my_app

      plug Plug.Static,
        at: "/",
        from: :my_app,
        gzip: false

      plug :router
    end
    """)

    File.write!(Path.join(css_dir, "app.css"), """
    @import "tailwindcss";
    @source "../../deps/phoenix_live_view";
    """)
  end

  setup %{tmp_dir: tmp_dir} do
    build_fixture(tmp_dir)
    original_cwd = File.cwd!()
    File.cd!(tmp_dir)
    on_exit(fn -> File.cd!(original_cwd) end)
    :ok
  end

  test "run/1 completes without error", %{tmp_dir: _tmp_dir} do
    # Should not raise
    Install.run([])
  end

  test "run/1 patches endpoint.ex with Plug.Static", %{tmp_dir: tmp_dir} do
    Install.run([])
    content = File.read!(Path.join(tmp_dir, "lib/my_app/endpoint.ex"))
    assert String.contains?(content, "phoenix_kit_legal")
  end

  test "run/1 patches app.css with @source", %{tmp_dir: tmp_dir} do
    Install.run([])
    content = File.read!(Path.join(tmp_dir, "assets/css/app.css"))
    assert String.contains?(content, "phoenix_kit_legal")
  end

  test "run/1 copies phoenix_kit_consent.js to assets/vendor/", %{tmp_dir: tmp_dir} do
    Install.run([])
    assert File.exists?(Path.join(tmp_dir, "assets/vendor/phoenix_kit_consent.js"))
  end

  test "run/1 prints next steps mentioning phoenix_kit.update", %{tmp_dir: _tmp_dir} do
    output =
      ExUnit.CaptureIO.capture_io(fn ->
        Mix.shell(Mix.Shell.IO)
        Install.run([])
      end)

    assert output =~ "phoenix_kit.update"
    assert output =~ "CookieConsent"
    assert output =~ "phoenix_kit_routes"
    assert output =~ "CookieConsent"
  end

  test "run/1 is idempotent — safe to call twice", %{tmp_dir: tmp_dir} do
    Install.run([])
    snapshot = read_tree(tmp_dir)

    Install.run([])
    assert read_tree(tmp_dir) == snapshot
  end

  # Reads all relevant files into a map for snapshot comparison.
  defp read_tree(base) do
    paths = [
      "lib/my_app/endpoint.ex",
      "assets/css/app.css",
      "assets/vendor/phoenix_kit_consent.js"
    ]

    Map.new(paths, fn rel ->
      full = Path.join(base, rel)
      {rel, if(File.exists?(full), do: File.read!(full), else: :missing)}
    end)
  end
end
