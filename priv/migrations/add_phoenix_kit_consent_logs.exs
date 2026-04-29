# priv/migrations/add_phoenix_kit_consent_logs.exs
# NOTE: Rename MyApp.Repo to your actual Repo module name.
defmodule MyApp.Repo.Migrations.AddPhoenixKitConsentLogs do
  use Ecto.Migration

  def change do
    create table(:phoenix_kit_consent_logs, primary_key: false) do
      # UUIDv7 maps to :uuid at the DB level (PostgreSQL UUID column)
      add :uuid, :uuid, primary_key: true
      add :user_uuid, :uuid, null: true
      add :session_id, :string, null: true
      add :consent_type, :string, null: false
      add :consent_given, :boolean, default: false, null: false
      add :consent_version, :string
      add :ip_address, :string
      add :user_agent_hash, :string
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:phoenix_kit_consent_logs, [:user_uuid])
    create index(:phoenix_kit_consent_logs, [:session_id])
    create index(:phoenix_kit_consent_logs, [:consent_type])
    create index(:phoenix_kit_consent_logs, [:inserted_at])
  end
end
