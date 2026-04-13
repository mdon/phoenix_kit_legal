defmodule Mix.Tasks.PhoenixKitLegal.InstallTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.PhoenixKitLegal.Install

  test "task module is defined" do
    assert Code.ensure_loaded?(Mix.Tasks.PhoenixKitLegal.Install)
  end

  test "task has @shortdoc" do
    assert Mix.Task.shortdoc(Mix.Tasks.PhoenixKitLegal.Install) =~ "Install"
  end

  describe "insert_plug_static/1" do
    setup do
      dir = System.tmp_dir!() |> Path.join("phoenix_kit_legal_test_#{:rand.uniform(100_000)}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)
      {:ok, dir: dir}
    end

    test "inserts Plug.Static before last existing Plug.Static", %{dir: dir} do
      path = Path.join(dir, "endpoint.ex")

      File.write!(path, """
      defmodule MyApp.Endpoint do
        use Phoenix.Endpoint, otp_app: :my_app

        plug Plug.Static,
          at: "/",
          from: :my_app,
          gzip: false

        plug :router
      end
      """)

      Install.insert_plug_static(path)

      content = File.read!(path)
      assert String.contains?(content, "phoenix_kit_legal")

      # Our plug must appear AFTER the existing Plug.Static block
      our_pos = :binary.match(content, "phoenix_kit_legal") |> elem(0)
      existing_pos = :binary.match(content, "at: \"/\",") |> elem(0)
      assert our_pos > existing_pos
    end

    test "idempotent — does not double-insert", %{dir: dir} do
      path = Path.join(dir, "endpoint.ex")

      File.write!(path, """
      defmodule MyApp.Endpoint do
        use Phoenix.Endpoint, otp_app: :my_app

        plug Plug.Static,
          at: "/phoenix_kit_legal",
          from: {:phoenix_kit_legal, "priv/static"},
          gzip: false

        plug :router
      end
      """)

      Install.insert_plug_static(path)
      content_after_first = File.read!(path)

      Install.insert_plug_static(path)
      content_after_second = File.read!(path)

      assert content_after_first == content_after_second

      occurrences =
        content_after_second
        |> String.split("phoenix_kit_legal")
        |> length()
        |> Kernel.-(1)

      # appears in snippet lines but not duplicated as a whole block
      assert occurrences >= 1
    end

    test "falls back to inserting before plug :router when no Plug.Static exists", %{dir: dir} do
      path = Path.join(dir, "endpoint.ex")

      File.write!(path, """
      defmodule MyApp.Endpoint do
        use Phoenix.Endpoint, otp_app: :my_app

        plug :router
      end
      """)

      Install.insert_plug_static(path)

      content = File.read!(path)
      assert String.contains?(content, "phoenix_kit_legal")

      our_pos = :binary.match(content, "phoenix_kit_legal") |> elem(0)
      router_pos = :binary.match(content, "plug :router") |> elem(0)
      assert our_pos < router_pos
    end

    test "handles multi-endpoint — each file is patched independently", %{dir: dir} do
      path1 = Path.join(dir, "endpoint_a.ex")
      path2 = Path.join(dir, "endpoint_b.ex")

      endpoint_content = """
      defmodule MyApp.Endpoint do
        plug Plug.Static, at: "/", from: :my_app, gzip: false
        plug :router
      end
      """

      File.write!(path1, endpoint_content)
      File.write!(path2, endpoint_content)

      Install.insert_plug_static(path1)
      Install.insert_plug_static(path2)

      assert File.read!(path1) |> String.contains?("phoenix_kit_legal")
      assert File.read!(path2) |> String.contains?("phoenix_kit_legal")
    end
  end

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
      # Appears after the last existing @source (trim trailing semicolon + newline from split boundary)
      [_, after_sources] = String.split(result, ~s(@source "../../deps/phoenix_live_view"), parts: 2)
      assert String.starts_with?(String.trim_leading(after_sources, ";\n"), ~s(@source "../../deps/phoenix_kit_legal"))
    end

    test "idempotent — does not duplicate if already present" do
      css = ~s(@source "../../deps/phoenix_kit_legal";\n)
      assert Mix.Tasks.PhoenixKitLegal.Install.insert_css_source(css) == css
    end
  end

  describe "copy_js_to_vendor/0" do
    test "source JS file exists in priv/static/assets" do
      src = Application.app_dir(:phoenix_kit_legal, "priv/static/assets/phoenix_kit_consent.js")
      assert File.exists?(src)
    end

    setup do
      dir = System.tmp_dir!() |> Path.join("phoenix_kit_legal_vendor_#{:rand.uniform(100_000)}")
      File.mkdir_p!(dir)
      original_cwd = File.cwd!()
      File.cd!(dir)
      on_exit(fn ->
        File.cd!(original_cwd)
        File.rm_rf!(dir)
      end)
      {:ok, dir: dir}
    end

    test "copies phoenix_kit_consent.js into assets/vendor/" do
      Install.copy_js_to_vendor()

      assert File.exists?("assets/vendor/phoenix_kit_consent.js")
      content = File.read!("assets/vendor/phoenix_kit_consent.js")
      assert byte_size(content) > 0
    end

    test "idempotent — does not overwrite if dest already exists" do
      File.mkdir_p!("assets/vendor")
      File.write!("assets/vendor/phoenix_kit_consent.js", "existing content")

      Install.copy_js_to_vendor()

      assert File.read!("assets/vendor/phoenix_kit_consent.js") == "existing content"
    end

    test "creates assets/vendor/ directory if missing" do
      refute File.exists?("assets/vendor")

      Install.copy_js_to_vendor()

      assert File.dir?("assets/vendor")
    end
  end
end
