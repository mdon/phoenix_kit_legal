defmodule PhoenixKitLegal.TranslatorTest do
  use ExUnit.Case, async: false

  alias PhoenixKitLegal.Translator

  # We can't easily mock PhoenixKitWeb.Gettext at compile time, so test the
  # `translate/2` runtime behavior by injecting a fake host backend. The core
  # backend (PhoenixKitWeb.Gettext) is the real one — we rely on the fact
  # that it has no Legal translations loaded for our test strings, so it
  # returns `{:default, msgid}` and the host-fallback path is exercised.

  defmodule FakeHostBackend do
    @moduledoc false

    def lgettext("uk", "default", nil, "Privacy Policy", _bindings),
      do: {:ok, "Політика конфіденційності"}

    def lgettext("uk", "default", nil, "Hello %{name}", %{name: name}),
      do: {:ok, "Привіт, #{name}"}

    def lgettext("xx", "default", nil, "Has Missing", _bindings),
      do: {:missing_bindings, "partial", [:foo]}

    def lgettext(_locale, _domain, _msgctxt, msgid, _bindings),
      do: {:default, msgid}
  end

  defmodule LocaleProbe do
    @moduledoc false

    def lgettext(locale, _, _, _, _) do
      send(self(), {:probe_locale, locale})
      {:default, ""}
    end
  end

  defmodule NotABackend do
    @moduledoc false

    def some_other_function, do: :ok
  end

  setup do
    Gettext.put_locale(PhoenixKitWeb.Gettext, "en")
    Application.delete_env(:phoenix_kit_legal, :host_gettext_backend)
    on_exit(fn -> Application.delete_env(:phoenix_kit_legal, :host_gettext_backend) end)
    :ok
  end

  test "returns msgid when neither core nor host have a translation" do
    assert Translator.translate("Some Untranslated String") == "Some Untranslated String"
  end

  test "host fallback returns host translation when core lacks one" do
    Application.put_env(:phoenix_kit_legal, :host_gettext_backend, FakeHostBackend)
    Gettext.put_locale(PhoenixKitWeb.Gettext, "uk")
    assert Translator.translate("Privacy Policy") == "Політика конфіденційності"
  end

  test "host fallback handles interpolation bindings" do
    Application.put_env(:phoenix_kit_legal, :host_gettext_backend, FakeHostBackend)
    Gettext.put_locale(PhoenixKitWeb.Gettext, "uk")
    assert Translator.translate("Hello %{name}", name: "Світ") == "Привіт, Світ"
  end

  test "missing_bindings on host returns partial string instead of crashing" do
    Application.put_env(:phoenix_kit_legal, :host_gettext_backend, FakeHostBackend)
    Gettext.put_locale(PhoenixKitWeb.Gettext, "xx")
    # Should not raise CaseClauseError
    assert Translator.translate("Has Missing") == "partial"
  end

  test "non-Gettext host backend (e.g. accidental misconfig) falls through safely" do
    Application.put_env(:phoenix_kit_legal, :host_gettext_backend, NotABackend)
    # Should NOT raise UndefinedFunctionError
    assert Translator.translate("Privacy Policy") == "Privacy Policy"
  end

  test "with_locale sets locale on core backend" do
    Translator.with_locale("uk", fn ->
      assert Gettext.get_locale(PhoenixKitWeb.Gettext) == "uk"
    end)

    # Locale restored after fun returns
    assert Gettext.get_locale(PhoenixKitWeb.Gettext) == "en"
  end

  test "with_locale sets locale on host backend when configured" do
    Application.put_env(:phoenix_kit_legal, :host_gettext_backend, LocaleProbe)

    Translator.with_locale("uk", fn ->
      Translator.translate("anything")
    end)

    assert_received {:probe_locale, "uk"}
  end
end
