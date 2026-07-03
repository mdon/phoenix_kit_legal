# PR #9 Review — Declare "legal" as a reserved top-level route prefix

**Repo:** `BeamLabEU/phoenix_kit_legal`
**Branch:** `timujinne:fix/reserve-legal-route-prefix` → `BeamLabEU:main`
**Reviewer:** Claude Sonnet 5
**Date:** 2026-07-03
**Related:** `BeamLabEU/phoenix_kit#614` (adds the callback + `ModuleRegistry.all_reserved_route_prefixes/0`), `BeamLabEU/phoenix_kit_publishing#29` (consults the registry in `RouterDispatch.known_group?/1`)
**Verdict:** **APPROVE** — implementation is correct and matches the new `phoenix_kit` contract exactly. One release-sequencing note below (not a code defect).

---

## Overview

Legal stores its generated pages as Publishing posts in a group slugged `"legal"`
(`@legal_blog_slug`). Publishing's `/:language/:group/*path` catch-all dispatch treats
any first path segment matching a stored group slug as one of its own groups, so
without a reservation mechanism it claims the host app's own `/legal` route before
that route ever matches — rendering Publishing's generic post view (wrong
canonical/og/hreflang) instead of the host's `LegalLive`. Confirmed in production per
the PR description.

`phoenix_kit` core PR #614 adds the fix's plumbing: an optional
`PhoenixKit.Module` callback `reserved_route_prefixes/0` (default `[]`,
`@optional_callbacks`), aggregated by `PhoenixKit.ModuleRegistry.all_reserved_route_prefixes/0`
across `all_modules/0`. `phoenix_kit_publishing` PR #29 makes `RouterDispatch.known_group?/1`
consult that aggregate before matching a path segment against its own group data.
This PR is Legal's half: implement the callback.

## Change

- `lib/phoenix_kit_legal/legal.ex:797-798` — `reserved_route_prefixes/0 -> [@legal_blog_slug]`
  (`@legal_blog_slug` is `"legal"`, `legal.ex:63`). Matches the contract exactly:
  `@callback reserved_route_prefixes() :: [String.t()]`, segments compared literally
  with no leading/trailing slash (`deps/phoenix_kit/lib/phoenix_kit/module.ex:255-278`).
- `mix.exs` — floors `{:phoenix_kit, "~> 1.7.170"}` (was `~> 1.7`). Necessary and correct:
  `@impl PhoenixKit.Module` on a callback the behaviour doesn't declare is a compile
  error, not a graceful no-op, and `reserved_route_prefixes/0` only exists in the
  behaviour from 1.7.170 on.
- `test/phoenix_kit_legal/reserved_route_prefixes_test.exs` — pins
  `reserved_route_prefixes() == ["legal"]`. Naming/namespacing matches the sibling
  `PhoenixKit.Modules.Legal.I18nTest` convention.

## Verification

- Confirmed against the actually-vendored dependency (not just the PR's own claims):
  `deps/phoenix_kit/lib/phoenix_kit/module.ex` declares `@callback reserved_route_prefixes()`
  and includes it in `@optional_callbacks` with a `[]` default — the `@impl` in
  `legal.ex` compiles cleanly against it.
  `PhoenixKit.ModuleRegistry.all_reserved_route_prefixes/0` calls it via `safe_call/3`
  and iterates `all_modules/0` (not `enabled_modules/0`) — correct per its own docstring,
  since a disabled module's compiled host route still exists and should stay protected.
- `mix.lock` already locks `phoenix_kit` `1.7.171` (bumped in the follow-up "lib upgrades"
  commit `5c1c424`), which is ≥ the new `~> 1.7.170` floor and does include the callback.
- **Format check (`[String.t()]`, no leading slash) matches**: `@legal_blog_slug` is
  `"legal"`, not `"/legal"` — no normalization needed on Legal's side, though
  `all_reserved_route_prefixes/0` would `String.trim/2` it either way.

## Findings

No blocking issues. One sequencing note, already disclosed in the PR description but
worth restating here so the CHANGELOG entry doesn't overclaim:

### NOTE — end-to-end protection isn't live yet; don't claim "fixed" until `phoenix_kit_publishing` republishes

This PR's change is inert on its own — `all_reserved_route_prefixes/0` is only ever
*read* by `phoenix_kit_publishing`'s dispatcher, and only as of PR #29. Checked both
companion PRs' actual state, not just their existence:

- `phoenix_kit#614` — merged 2026-07-03T13:59:40Z, and **is** already published: Hex's
  latest `phoenix_kit` is `1.7.171`, which is what `mix.lock` here locks. ✅ live.
- `phoenix_kit_publishing#29` — merged 2026-07-03T18:39:17Z, but **not yet published**:
  Hex's latest `phoenix_kit_publishing` is still `0.2.2`, released 2026-06-19 (two weeks
  *before* #29 merged). Verified directly in the vendored dep — `deps/phoenix_kit_publishing`
  (locked to `0.2.2`) has no reference to `reserved_route_prefixes` or
  `all_reserved_route_prefixes` anywhere in its `RouterDispatch`/`known_group?/1` code.

So today, a host app on the latest published releases of everything still has the
`/legal`-hijack bug — this PR (and #614) are necessary but not yet sufficient. No
action needed in *this* repo (`mix.exs` correctly leaves `phoenix_kit_publishing` at
`~> 0.1`, which will pick up the fix automatically via `mix deps.update` once a new
version publishes — no floor bump needed here since the consultation is entirely on
the reader's side). Flagging so the CHANGELOG entry for this release describes what
Legal now *declares*, not that the hijack is resolved end-to-end — that claim belongs
in `phoenix_kit_publishing`'s own changelog once it republishes.

## Positives

- **Correct on the first attempt.** Verified against the actual callback contract
  (name, arity, return shape, `@optional_callbacks` presence) in the vendored
  dependency rather than trusting the PR description — matches exactly.
- **Necessary, minimal dependency floor bump**, with a comment explaining *why* it's
  not optional (`@impl` on an undeclared callback is a hard compile error) rather than
  just bumping silently.
- **Test pins the exact contract value** (`["legal"]`, not `"/legal"` or a bare string),
  guarding against the malformed-return footguns `all_reserved_route_prefixes/0`'s
  own docstring calls out.
- **Correctly scoped.** Doesn't try to reach into `phoenix_kit_publishing` or bump its
  floor — that fix lives and ships on its own schedule.

## Test Plan

- [x] `mix precommit` (format + `compile --warnings-as-errors` + `deps.unlock --check-unused`
  + `hex.audit` + `credo --strict` + `dialyzer`) — see gate output in this session.
- [x] `mix test` — full suite, including the new pinning test.
- [ ] In-app (blocked on `phoenix_kit_publishing` republishing #29): once a host app is
  on `phoenix_kit_publishing` ≥ the version containing #29, hit `/legal` and confirm it
  renders the host's `LegalLive`, not Publishing's generic post view.
