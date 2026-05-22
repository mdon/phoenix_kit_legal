# PR #8 Review — Implement version-tracking protocol in `ConsentLogs`

**Repo:** `BeamLabEU/phoenix_kit_legal`
**Branch:** `timujinne:fix/consentlogs-version-tracking` → `BeamLabEU:main`
**Reviewer:** Claude Opus 4.7
**Date:** 2026-05-22
**Tracking issue:** `timujinne/phoenix_kit_legal#1`
**Verdict:** **APPROVE** — fix is minimal, correct, and matches the protocol Core (V121) expects.

---

## Overview

PhoenixKit Core v1.7.119 (schema V121) introduced a versioned-migration protocol for
external modules. `mix phoenix_kit.update` discovers modules exporting
`migration_module/0` and calls, on that migration module:

- `migrated_version_runtime(prefix: prefix)` — currently applied schema version;
- `current_version()` — target schema version.

`PhoenixKit.Modules.Legal.migration_module/0` (`legal.ex:787`) returns
`PhoenixKit.Modules.Legal.Migrations.ConsentLogs`, but that module only implemented
`up/1` and `down/1` and matched a **map** argument. Two defects resulted:

1. `current_version/0` and `migrated_version_runtime/1` were undefined → Core's
   `try/rescue` swallowed the error and **skipped the Legal migration entirely**.
2. Core passes a **keyword list** (`up(prefix: "public", version: 1)`), which would
   not match the old `up(%{prefix: prefix})` clause → `FunctionClauseError`.

On a clean install this meant `phoenix_kit_consent_logs` was never created.

## Change

Single file: `lib/phoenix_kit_legal/migrations/consent_logs.ex`.

- Adds `current_version/0` → `1` (one consolidated migration).
- Adds `migrated_version_runtime/1` → `0` if `phoenix_kit_consent_logs` is absent,
  `1` if present. Uses `SELECT to_regclass($1)` via `PhoenixKit.RepoHelper.repo()`
  (already a dependency — `consent_log.ex:292`). Wrapped in `rescue _ -> 0`.
- `up/1` and `down/1` now accept both keyword lists (Core's form) and maps (legacy
  form) through a private `normalize_prefix/1`. CREATE/DROP SQL is unchanged.

No change to `mix.exs` `@version` or `CHANGELOG.md` (HARD RULE per prior reviews).

## Findings

No blocking issues.

### NITPICK

- The `:version` key Core passes to `up/1`/`down/1` is intentionally ignored — the
  Legal module is a single consolidated migration, so the target is always `1`.
  This matches the reference behaviour in the issue. If Legal ever gains a second
  schema version, `up/1` will need to branch on `opts[:version]`.
- `migrated_version_runtime/1` reports only `0`/`1` by table existence, not by an
  oban-style `migrations` version row. Correct for a one-version module; revisit if
  the module gains incremental migrations.

## Positives

- **Minimal blast radius.** One file, SQL bodies untouched — the table definition
  and indexes are byte-for-byte identical to before.
- **Backward compatible.** `normalize_prefix/1` accepts keyword list, map, and
  anything else (→ `"public"`), so any legacy caller passing a map still works.
- **Idempotent.** `CREATE TABLE IF NOT EXISTS` / `DROP TABLE IF EXISTS` preserved;
  re-running on an already-migrated DB is safe, and `migrated_version_runtime/1`
  correctly reports `1` there so Core skips regeneration.
- **No new dependency.** `PhoenixKit.RepoHelper` is already used by the module's
  schema.
- **Matches the Core reference** (`PhoenixKit.Migrations.Postgres.current_version/0`
  + `migrated_version_runtime/1`).

## Test Plan

- [x] `mix deps.get` + `mix compile` — clean, no warnings on `phoenix_kit_legal`.
- [x] `mix format --check-formatted` — clean.
- [x] `mix test` — 36 tests, 0 failures.
- [ ] In-app: update parent app to Core ≥ v1.7.119 and run `mix phoenix_kit.update -y`
  — verify no `migrated_version_runtime/1 is undefined` warning and that
  `phoenix_kit_consent_logs` is created on a clean DB. (Pending; requires a parent
  app on the new Core.)
