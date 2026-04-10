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
end
