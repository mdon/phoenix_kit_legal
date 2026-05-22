defmodule PhoenixKit.Modules.Legal.Migrations.ConsentLogs do
  @moduledoc """
  Consolidated migration for the Legal module.

  Creates the `phoenix_kit_consent_logs` table.
  All statements use IF NOT EXISTS guards — safe to run multiple times.

  Implements the versioned-migration protocol expected by PhoenixKit Core
  (`mix phoenix_kit.update`): `current_version/0` and
  `migrated_version_runtime/1`. Reference implementation —
  `PhoenixKit.Migrations.Postgres` in Core.
  """

  use Ecto.Migration

  @current_version 1

  @doc "Целевая версия схемы Legal-модуля."
  def current_version, do: @current_version

  @doc """
  Текущая применённая версия схемы из БД.

  Возвращает `0`, если таблицы `phoenix_kit_consent_logs` ещё нет,
  и `#{@current_version}`, если она уже создана. `opts` — keyword list
  с опциональным `:prefix`.
  """
  def migrated_version_runtime(opts \\ []) do
    prefix = normalize_prefix(opts)

    table =
      if prefix == "public",
        do: "public.phoenix_kit_consent_logs",
        else: "#{prefix}.phoenix_kit_consent_logs"

    case PhoenixKit.RepoHelper.repo().query("SELECT to_regclass($1)", [table]) do
      {:ok, %{rows: [[nil]]}} -> 0
      {:ok, %{rows: [[_oid]]}} -> @current_version
      _ -> 0
    end
  rescue
    _ -> 0
  end

  @doc """
  Применяет миграцию Legal-модуля.

  Принимает keyword list (так его передаёт Core) или map — для обратной
  совместимости.
  """
  def up(opts \\ []) do
    prefix = normalize_prefix(opts)
    prefix_str = prefix_str(prefix)

    execute("""
    CREATE TABLE IF NOT EXISTS #{prefix_str}phoenix_kit_consent_logs (
      uuid UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
      user_uuid UUID,
      session_id VARCHAR(255),
      consent_type VARCHAR(50) NOT NULL,
      consent_given BOOLEAN NOT NULL DEFAULT false,
      consent_version VARCHAR(50),
      ip_address VARCHAR(45),
      user_agent_hash VARCHAR(64),
      metadata JSONB NOT NULL DEFAULT '{}',
      inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS idx_consent_logs_user_uuid
    ON #{prefix_str}phoenix_kit_consent_logs (user_uuid)
    WHERE user_uuid IS NOT NULL
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS idx_consent_logs_session_id
    ON #{prefix_str}phoenix_kit_consent_logs (session_id)
    WHERE session_id IS NOT NULL
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS idx_consent_logs_consent_type
    ON #{prefix_str}phoenix_kit_consent_logs (consent_type)
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS idx_consent_logs_inserted_at
    ON #{prefix_str}phoenix_kit_consent_logs (inserted_at DESC)
    """)
  end

  @doc """
  Откатывает миграцию Legal-модуля.

  Принимает keyword list (так его передаёт Core) или map — для обратной
  совместимости.
  """
  def down(opts \\ []) do
    prefix_str = prefix_str(normalize_prefix(opts))
    execute("DROP TABLE IF EXISTS #{prefix_str}phoenix_kit_consent_logs CASCADE")
  end

  # Core передаёт keyword list (`prefix: "public", version: 1`);
  # прежний механизм — map (`%{prefix: "public"}`). Поддерживаем оба.
  defp normalize_prefix(opts) when is_list(opts), do: opts[:prefix] || "public"
  defp normalize_prefix(%{prefix: prefix}), do: prefix || "public"
  defp normalize_prefix(_), do: "public"

  defp prefix_str(prefix) when prefix in [nil, "public"], do: ""
  defp prefix_str(prefix), do: "#{prefix}."
end
