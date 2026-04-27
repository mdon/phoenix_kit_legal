defmodule PhoenixKitLegal.Gettext do
  @moduledoc """
  Indirection layer that lets the host app override the Gettext backend used by
  `phoenix_kit_legal` modules.

  Defaults to `PhoenixKitWeb.Gettext` (shipped with `phoenix_kit` core), so
  existing setups keep working. Host apps with their own Gettext backend and
  translation files can opt in:

      config :phoenix_kit_legal, :gettext_backend, MyAppWeb.Gettext

  Then `use PhoenixKitLegal.Gettext` resolves to the configured backend at
  compile time, and `mix gettext.extract --merge` in the host app will pick up
  every translatable string from `phoenix_kit_legal`.

  The configured backend module is also exposed as `backend/0` for the few
  call sites that need it dynamically (e.g. `Gettext.with_locale/3`).
  """

  @backend Application.compile_env(
             :phoenix_kit_legal,
             :gettext_backend,
             PhoenixKitWeb.Gettext
           )

  @doc "Returns the Gettext backend module configured for `phoenix_kit_legal`."
  def backend, do: @backend

  defmacro __using__(_opts) do
    backend = @backend

    quote do
      use Gettext, backend: unquote(backend)
    end
  end
end
