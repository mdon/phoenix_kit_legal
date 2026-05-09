# Changelog

## 0.1.4 (2026-05-09)

### Changed
- All module-owned `gettext` calls now resolve through `PhoenixKit.Modules.Legal.Gettext` instead of the parent app's `PhoenixKitWeb.Gettext` — completes the per-module-i18n migration started in 0.1.3 (`legal.ex`, `web/cookie_consent.ex`, `web/settings.ex`)
- `translate_title/2` resolves page titles against the module's own catalogue under `priv/gettext/`, so generated legal pages get titles in the user's locale even on parent apps that don't translate these strings themselves
- `priv/gettext/default.pot` is now auto-extracted (`mix gettext.extract --merge`) — covers tab labels, page titles, consent-widget UI, and admin flash messages (126 msgids); `__extract_strings__/0` seeds runtime-only strings for the extractor

### Added
- Russian (`ru`) and Estonian (`et`) translations for the entire catalogue: consent-widget banner / modal / category names, page titles, settings labels, flash messages
- `Plural-Forms` header on `priv/gettext/en/LC_MESSAGES/default.po`
- Per-locale tests for the module's own catalogue (`translate/2` smoke tests covering page titles + consent-widget strings) — runnable against any `phoenix_kit` release; tab-label tests remain gated behind `:requires_phoenix_kit_i18n_api` until [BeamLabEU/phoenix_kit#522](https://github.com/BeamLabEU/phoenix_kit/pull/522) ships

### Notes
- Sidebar tab label still falls back to the raw "Legal" string on `phoenix_kit` ≤ 1.7.105: `Tab.localized_label/1` and the `gettext_backend:` field on `%Tab{}` ship with phoenix_kit#522, which is unmerged. Consent-widget strings and page titles already resolve per-locale on the published `phoenix_kit` because they're rendered live from our own modules.

## 0.1.3 (2026-04-30)

### Added
- `mix phoenix_kit_legal.install` task — auto-patches host app's `endpoint.ex` (Plug.Static), `assets/css/app.css` (Tailwind `@source`), and `assets/js/app.js` (consent IIFE import); idempotent
- `migration_module/0` callback returning `PhoenixKit.Modules.Legal.Migrations.ConsentLogs` — migration runs via `mix phoenix_kit.update`
- i18n: `Legal.get_consent_widget_config/0` returns a `translations` map (banner / modal / categories); JS reads via `t()` / `tc()` helpers with English fallbacks
- Legal page titles translated at generation time via `Gettext.with_locale/3` so per-language Publishing slots receive the title in the right language
- New `phoenix_kit_current_scope` attr on `cookie_consent/1` — component decides server-side whether to render for authenticated users

### Changed
- Server-side auth gate for cookie consent widget: `cookie_consent/1` now returns `~H""` for authenticated users when `hide_for_authenticated?` is true, eliminating the client-side flash and the auth round-trip
- Default for `legal_hide_for_authenticated` flipped from `false` to `true` — existing installs that want the widget visible to authenticated users must set this explicitly in Admin → Legal
- `/api/consent-config` cache header changed from `public, max-age=60` to `private, max-age=60` (translations are locale-dependent)
- Locale prefix dropped from widget links (`/en/legal` → `/legal`) so the parent app's locale plug picks the user's current locale on click
- `css_sources/0` returns `[:phoenix_kit_legal, @source_root]` — absolute source root included for path-dep installs

### Removed
- `should_show`, `is_authenticated`, `hide_for_authenticated` fields from `/api/consent-config` JSON response — auth-gating is now server-side only
- `resetGoogleConsentMode` JS helper — over-broad heuristic, removed

### Fixed
- Banner and modal no longer hidden by Tailwind's `hidden` class `!important`
- Consent widget initializes reliably from `DOMContentLoaded` outside LiveView scope
- Server-rendered consent HTML preserved (no JS re-injection layout flicker)
- HTML escaping (`escapeAttr` / `escapeText`) applied to user-controlled URLs and translation strings in the JS injection path
- Component accepts `cookie_policy_url` / `privacy_policy_url` / `legal_links` again as no-op attrs for backward compatibility with PhoenixKit default layouts

### Internal
- Test infrastructure: `test_helper.exs` starts `PhoenixKit.Cache.Registry` and `:settings` cache for component tests
- Credo `--strict` clean (resolved 5 nested-module references in tests, 1 single-branch `cond`, 1 deeply-nested function)
- Dialyzer clean (`:mix` added to `plt_add_apps`)

### Migration notes
- Recommended (not required): add `phoenix_kit_current_scope={@phoenix_kit_current_scope}` to your `<.cookie_consent ...>` call so the "Hide for authenticated users" admin setting takes effect. Without it the widget renders for everyone.

## 0.1.2 (2026-04-05)

- Fix Legal settings route 404 by adding missing `live_view` field to settings tab definition
- Add `version/0` callback to display actual package version on modules page
- Add `elixirc_options: [ignore_module_conflict: true]` for umbrella compatibility
- Update dependencies to latest versions

## 0.1.1 (2026-04-02)

- Migrate select elements to daisyUI 5 label wrapper pattern
- Remove deprecated `select-bordered` class for daisyUI 5 compatibility
- Add `live_view` to settings tab for auto route discovery
- Add `css_sources/0` callback
- Fix legal page generation for existing/trashed posts

## 0.1.0 (2026-03-27)

- Initial extraction from PhoenixKit core
- Legal page generation (Privacy Policy, Cookie Policy, Terms of Service, etc.)
- Cookie consent widget with Google Consent Mode v2
- GDPR, CCPA, LGPD, PIPEDA compliance frameworks
- Consent logging schema
