# PR #6 — Add per-module Gettext backend for sidebar tab label

**Author:** @timujinne
**Branch:** `feature/per-module-i18n` → `main`
**Status at review:** MERGED (commit `2133db8`)
**Reviewer:** Claude (Opus 4.7)
**Date:** 2026-05-09

## Summary

The PR introduces `PhoenixKit.Modules.Legal.Gettext` — a per-module Gettext
backend — and ships translation catalogues for `en`, `ru`, `et` so that the
admin sidebar tab labelled "Legal" can be resolved against the active
user locale once the consumer's `phoenix_kit` resolves to a release
that ships PR [BeamLabEU/phoenix_kit#522](https://github.com/BeamLabEU/phoenix_kit/pull/522)
(adds `Tab.localized_label/1` + the `gettext_backend:` / `gettext_domain:`
fields on `%Tab{}`).

The change is small, well-bounded, and forward-compatible: on the
currently published `phoenix_kit` (1.7.102), `Tab.new!` silently drops
the unknown `gettext_backend:` and `gettext_domain:` keys — verified
against `deps/phoenix_kit/lib/phoenix_kit/dashboard/tab.ex:264`
(`build_tab_struct/2` only assigns known fields via `get_attr/2`).
The associated test module is gated by a tag (`:requires_phoenix_kit_i18n_api`)
and excluded automatically by `test/test_helper.exs` until the API is
available.

## Verdict

**Approved (already merged).** Direction is correct, the wiring is
forward-compatible, the test gating is graceful. The PR author flagged
real residual tech debt as out-of-scope (line 35 of `legal.ex`,
lines 1026–1027) — that debt is what this review proposes to address
in a follow-up patch on `main` (see "Improvements we own and ship next").

## What's good

- **Forward-compatible wiring.** `Tab.new!(... gettext_backend: ..., gettext_domain: ...)`
  works on the currently published `phoenix_kit` because unknown keys
  are silently dropped by `build_tab_struct/2`. No version pin, no
  conditional compilation, no `Code.ensure_loaded?` dance at the
  registration site.
- **Tests are gated by capability, not version.** `test_helper.exs`
  uses `function_exported?(PhoenixKit.Dashboard.Tab, :localized_label, 1)`
  to detect the new API at test-time. The moment the consumer's
  `phoenix_kit` dep resolves to a release that ships PR #522, the
  i18n suite runs automatically — no follow-up edit needed.
- **Module-owned `priv/gettext/` catalogue.** `mix.exs` `package files:`
  already includes `priv`, so the `.po` files ship to Hex consumers.
  The backend module itself is a one-liner over `Gettext.Backend`.
- **Honest scope statement.** The PR description explicitly enumerates
  what is *not* migrated and why (line 35 `use Gettext` + lines
  1026–1027 `Gettext.with_locale(PhoenixKitWeb.Gettext, ...)`),
  rather than silently leaving them in place.

## Issues / observations

### 1. Migration is incomplete — most module-owned strings still resolve via parent backend (out-of-scope per PR, in-scope for follow-up)

The PR self-identifies this:

> `lib/phoenix_kit_legal/legal.ex` retains a pre-existing
> `use Gettext, backend: PhoenixKitWeb.Gettext` (line 35) and two
> `Gettext.with_locale(PhoenixKitWeb.Gettext, …)` /
> `Gettext.gettext(PhoenixKitWeb.Gettext, …)` calls (lines 1026–1027).
> These are NOT introduced by this PR — they pre-date the per-module-i18n
> migration and are out of scope.

A grep across the working tree shows this isn't only `legal.ex` —
`web/cookie_consent.ex:29` and `web/settings.ex:16` also `use Gettext, backend: PhoenixKitWeb.Gettext`,
covering the entire consent widget UI (~25 strings) and admin
settings flash messages (~15 strings). With the module's own backend
present and translations shipping via Hex, the right next step is to
flip these too so the module owns its translation surface end-to-end.

**Risk of the migration:** any string we move to our backend that
the parent app *was* translating goes back to its English msgid
unless we ship a translation. Mitigated by:

1. Most consent widget strings are domain-specific to this module
   (e.g. "We value your privacy") and unlikely to appear in the
   parent's catalog.
2. We ship `ru` and `et` translations for the high-value strings as
   part of the follow-up.

**Locale propagation:** safe under modern Gettext semantics.
`Gettext.put_locale/1` (the unary form parent apps call in their
`:set_locale` plug) sets a *global* per-process locale; per-backend
locale set via `Gettext.put_locale/2` is only an override.
`Gettext.get_locale(OurBackend)` falls back to the global locale
when no backend-specific one is set — verified to be the documented
behavior of `:gettext` ~> 1.0.

### 2. `__extract_titles__/0` is a workaround that survives the migration

`legal.ex:1009-1023` defines a never-called function whose only
purpose is to mark page titles for `mix gettext.extract`. With
the module's own backend, this still works — the function calls
`gettext(...)` macros that route to whatever backend `use Gettext`
declares. After the follow-up flip (issue #1), these extract into
**our** `priv/gettext/default.pot` rather than the parent's. The
workaround stays, but the comment should be updated to reflect that
extraction now targets the module-local catalogue.

### 3. `default.pot` is "manually maintained" — consider auto-extraction for the tab label

The current `priv/gettext/default.pot` has a manual comment
explaining that tab labels can't be auto-extracted because they
live as plain strings in `Tab.new!(label: ...)`. This is true and
reasonable today, but: once issue #1 is addressed, the module
already has machinery (`__extract_titles__/0`) for "give the
extractor a string it would otherwise miss". A symmetric
`__extract_tab_labels__/0` would let `mix gettext.extract --merge`
handle the entire catalogue — no more "edit `.pot` by hand" footgun
for future tab additions.

### 4. en/LC_MESSAGES/default.po lacks Plural-Forms header

`priv/gettext/en/LC_MESSAGES/default.po` has only `"Language: en\n"`.
`ru` and `et` both ship a `Plural-Forms` header. English usually
ships `"Plural-Forms: nplurals=2; plural=(n != 1);\n"`. Cosmetic,
but tools like Poedit warn about it. Easy to add when running
`mix gettext.merge --locale en`.

### 5. `gettext_domain: "default"` is the gettext default

`Tab.new!(... gettext_domain: "default")` is explicit but redundant
under the proposed phoenix_kit#522 API (which uses `"default"` when
the field is unset). Minor — explicitness is fine for clarity. Not
worth changing.

### 6. Test coverage is tab-only

The smoke tests cover the tab label round-trip but not the
consent widget translations or the page-title `translate_title/2`
helper. After the follow-up migration (issue #1), at least one
assertion per category — banner string, modal string, page title —
would catch a missing `.po` entry before it ships to users. Low
priority; the catalogue is small enough that a wrong msgid is
visible immediately.

## Improvements we own and ship next

Concrete follow-up plan to address issues #1–#3 in this same
working tree (separate commit from the PR-merge):

1. **Flip `use Gettext, backend: PhoenixKitWeb.Gettext` →
   `use Gettext, backend: PhoenixKit.Modules.Legal.Gettext`** in:
   - `lib/phoenix_kit_legal/legal.ex` (line 35)
   - `lib/phoenix_kit_legal/web/cookie_consent.ex` (line 29)
   - `lib/phoenix_kit_legal/web/settings.ex` (line 16)
2. **Update `translate_title/2`** (`legal.ex:1025-1029`) to use the
   module's backend instead of `PhoenixKitWeb.Gettext`.
3. **Replace `__extract_titles__/0`** comment to reflect that
   extraction targets the module-local catalogue. Add an
   `__extract_tab_labels__/0` so `mix gettext.extract --merge`
   handles every translatable label, including tab labels.
4. **Run `mix gettext.extract --merge priv/gettext`** to
   regenerate `default.pot` and propagate to `en` / `ru` / `et`
   `.po` files.
5. **Provide RU and ET translations** for the most user-visible
   strings (consent widget banner + modal + 4 categories + 7
   page titles). EN file gets `Plural-Forms` header.
6. **Run `mix precommit`** — must pass with zero warnings before
   committing.

## Files reviewed

```
M  CHANGELOG.md
M  mix.exs
A  lib/phoenix_kit_legal/gettext.ex
M  lib/phoenix_kit_legal/legal.ex
A  priv/gettext/default.pot
A  priv/gettext/en/LC_MESSAGES/default.po
A  priv/gettext/et/LC_MESSAGES/default.po
A  priv/gettext/ru/LC_MESSAGES/default.po
A  test/phoenix_kit_legal/i18n_test.exs
M  test/test_helper.exs
```

## Cross-references

- PR #6: <https://github.com/BeamLabEU/phoenix_kit_legal/pull/6>
- Upstream API PR (open): <https://github.com/BeamLabEU/phoenix_kit/pull/522>
- Tab struct (current Hex): `deps/phoenix_kit/lib/phoenix_kit/dashboard/tab.ex:155-183`
- Tab struct construction: `deps/phoenix_kit/lib/phoenix_kit/dashboard/tab.ex:233-263`
