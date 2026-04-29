defmodule PhoenixKit.Modules.Legal.Migrations.ConsentLogs do
  @moduledoc """
  Consolidated migration for the Legal module.

  Creates the `phoenix_kit_consent_logs` table.
  All statements use IF NOT EXISTS guards — safe to run multiple times.
  """

  use Ecto.Migration

  def up(%{prefix: prefix} = _opts) do
    prefix_str = if prefix && prefix != "public", do: "#{prefix}.", else: ""

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

  def down(%{prefix: prefix} = _opts) do
    prefix_str = if prefix && prefix != "public", do: "#{prefix}.", else: ""
    execute("DROP TABLE IF EXISTS #{prefix_str}phoenix_kit_consent_logs CASCADE")
  end
end
