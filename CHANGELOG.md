# Changelog

## 0.1.3 (2026-05-08)

### Added
- Per-module Gettext backend (`PhoenixKit.Modules.Legal.Gettext`) with `en`/`ru`/`et` catalogues for the admin sidebar "Legal" settings tab label. Requires `phoenix_kit` release that ships the `gettext_backend` Tab API ([BeamLabEU/phoenix_kit#522](https://github.com/BeamLabEU/phoenix_kit/pull/522)); on older releases tabs render raw English (graceful degradation).

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
