defmodule PhoenixKitWeb.Controllers.ConsentConfigController do
  @moduledoc """
  API controller for cookie consent widget configuration.

  Returns the consent widget configuration as JSON for client-side initialization.

  This endpoint is intentionally auth-agnostic by design: it performs no
  per-request user check. Whether to show the widget to an authenticated
  user is decided server-side by the `cookie_consent` component at render
  time (via its `phoenix_kit_current_scope` attribute).

  The response embeds locale-dependent `translations`, so it is marked
  `cache-control: private` to allow per-user browser caching while
  preventing shared/CDN caches from serving one locale's translations
  to a user expecting another locale.

  Used by the manual `window.PhoenixKitConsent.init()` entry point for
  third-party / non-LiveView injection contexts. Because this endpoint does
  not gate on auth, manual callers of `init()` are responsible for
  implementing their own auth checks before invoking it on pages where
  authenticated users should not see the widget.
  """
  use PhoenixKitWeb, :controller

  alias PhoenixKit.Modules.Legal

  @doc """
  Returns the consent widget configuration as JSON.
  """
  def config(conn, _params) do
    conn
    |> put_resp_header("cache-control", "private, max-age=60")
    |> json(Legal.get_consent_widget_config())
  end
end
