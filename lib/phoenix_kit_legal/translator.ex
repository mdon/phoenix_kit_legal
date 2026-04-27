defmodule PhoenixKitLegal.Translator do
  @moduledoc """
  Resolves Legal-module strings with an optional host-app fallback.

  Default lookup goes to `PhoenixKitWeb.Gettext` (phoenix_kit core), where
  Legal translations are extracted and shipped. Host applications may opt in
  to provide translations for locales/strings that core doesn't yet ship:

      config :phoenix_kit_legal, :host_gettext_backend, MyAppWeb.Gettext

  Without that config, behaviour is byte-identical to direct
  `PhoenixKitWeb.Gettext` usage. Once a string lands in core, the host
  fallback is skipped automatically.

  ## Usage in library code

      import PhoenixKitLegal.Translator, only: [t: 1, t: 2]

      t("Privacy Policy")
      t("Generated %{count} pages", count: 5)

  The `t/1` and `t/2` macros (a) emit
  `Gettext.Macros.gettext_noop_with_backend(PhoenixKitWeb.Gettext, msgid)` for
  compile-time extraction into phoenix_kit core's `.pot` and (b) call
  `translate/1`/`translate/2` at runtime for the actual lookup.
  """

  require Gettext.Macros

  @core_backend PhoenixKitWeb.Gettext

  @doc """
  Compile-time extraction marker + runtime fallback for a static string.
  """
  defmacro t(msgid) when is_binary(msgid) do
    quote do
      require Gettext.Macros

      _ =
        Gettext.Macros.gettext_noop_with_backend(
          PhoenixKitWeb.Gettext,
          unquote(msgid)
        )

      PhoenixKitLegal.Translator.translate(unquote(msgid))
    end
  end

  @doc """
  Compile-time extraction marker + runtime fallback for an interpolated string.

      t("Hello %{name}", name: "World")
  """
  defmacro t(msgid, bindings) when is_binary(msgid) do
    quote do
      require Gettext.Macros

      _ =
        Gettext.Macros.gettext_noop_with_backend(
          PhoenixKitWeb.Gettext,
          unquote(msgid)
        )

      PhoenixKitLegal.Translator.translate(
        unquote(msgid),
        unquote(bindings)
      )
    end
  end

  @doc """
  Look up `msgid` in core first, then in the host backend if configured.
  Returns `msgid` if neither source provides a translation.
  """
  @spec translate(String.t(), Enum.t()) :: String.t()
  def translate(msgid, bindings \\ %{}) when is_binary(msgid) do
    locale = Gettext.get_locale(@core_backend)
    bindings_map = Map.new(bindings)

    case @core_backend.lgettext(locale, "default", nil, msgid, bindings_map) do
      {:ok, translated} -> translated
      {:default, default} -> host_fallback(locale, msgid, bindings_map, default)
    end
  end

  defp host_fallback(locale, msgid, bindings_map, default) do
    case Application.get_env(:phoenix_kit_legal, :host_gettext_backend) do
      nil ->
        default

      backend when is_atom(backend) ->
        if Code.ensure_loaded?(backend) do
          case backend.lgettext(locale, "default", nil, msgid, bindings_map) do
            {:ok, translated} -> translated
            _ -> default
          end
        else
          default
        end
    end
  end

  @doc """
  Run `fun` with the given locale set on the core backend (and the host
  backend if configured). Restores prior locales on exit.

  Wraps `Gettext.with_locale/3` for both backends so dynamic translations
  (e.g. legal page titles generated for a specific language) hit both
  lookup tiers.
  """
  @spec with_locale(String.t(), (-> any())) :: any()
  def with_locale(locale, fun) when is_binary(locale) and is_function(fun, 0) do
    host = Application.get_env(:phoenix_kit_legal, :host_gettext_backend)

    Gettext.with_locale(@core_backend, locale, fn ->
      if host && Code.ensure_loaded?(host) do
        Gettext.with_locale(host, locale, fun)
      else
        fun.()
      end
    end)
  end
end
