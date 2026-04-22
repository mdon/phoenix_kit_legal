defmodule PhoenixKitWeb.Controllers.ConsentConfigController do
  @moduledoc """
  API controller for cookie consent widget configuration.

  Returns the consent widget configuration as JSON for client-side initialization.
  This endpoint is intentionally auth-agnostic: whether to show the widget to an
  authenticated user is decided server-side by the `cookie_consent` component at
  render time (via its `phoenix_kit_current_scope` attribute).

  Used by the manual `window.PhoenixKitConsent.init()` entry point for third-party
  / non-LiveView injection contexts.
  """
  use PhoenixKitWeb, :controller

  alias PhoenixKit.Modules.Legal

  @doc """
  Returns the consent widget configuration as JSON.
  """
  def config(conn, _params) do
    conn
    |> put_resp_header("cache-control", "public, max-age=60")
    |> json(Legal.get_consent_widget_config())
  end
end
