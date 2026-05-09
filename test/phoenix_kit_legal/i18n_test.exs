defmodule PhoenixKit.Modules.Legal.I18nTest do
  @moduledoc """
  Smoke test for the per-module i18n wiring.

  Confirms that:
    * The settings tab registered by `PhoenixKit.Modules.Legal.settings_tabs/0`
      carries `gettext_backend: PhoenixKit.Modules.Legal.Gettext`.
    * Locale switching on the module's own backend produces translated
      labels for the well-known "Legal" msgid (regression guard for
      the `priv/gettext/<locale>/LC_MESSAGES/default.po` shipping with
      the package).
    * Falls back to the raw msgid for an unknown locale.
  """

  use ExUnit.Case, async: false

  # Excluded by `test/test_helper.exs` when running against a `phoenix_kit`
  # release that pre-dates the `gettext_backend` API (PR BeamLabEU/phoenix_kit#522).
  # Once the consumer's `phoenix_kit` dep resolves to a release that ships
  # `Tab.localized_label/1`, the helper detects it and these tests run
  # automatically — no follow-up edit needed.
  @moduletag :requires_phoenix_kit_i18n_api

  alias PhoenixKit.Dashboard.Tab
  alias PhoenixKit.Modules.Legal
  alias PhoenixKit.Modules.Legal.Gettext, as: LegalGettext

  setup do
    original = Gettext.get_locale(LegalGettext)
    on_exit(fn -> Gettext.put_locale(LegalGettext, original) end)
    :ok
  end

  describe "settings_tabs/0 wiring" do
    test "every tab carries the module's own gettext backend" do
      for tab <- Legal.settings_tabs() do
        assert tab.gettext_backend == LegalGettext,
               "Tab #{inspect(tab.id)} is missing or wrong gettext_backend " <>
                 "(got #{inspect(tab.gettext_backend)})"

        assert tab.gettext_domain == "default"
      end
    end
  end

  describe "Tab.localized_label/1 against the module's catalogue" do
    test "ru locale resolves 'Legal' to 'Юридические документы'" do
      Gettext.put_locale(LegalGettext, "ru")

      tab = Enum.find(Legal.settings_tabs(), &(&1.id == :admin_settings_legal))
      assert Tab.localized_label(tab) == "Юридические документы"
    end

    test "et locale resolves 'Legal' to 'Õigusdokumendid'" do
      Gettext.put_locale(LegalGettext, "et")

      tab = Enum.find(Legal.settings_tabs(), &(&1.id == :admin_settings_legal))
      assert Tab.localized_label(tab) == "Õigusdokumendid"
    end

    test "unknown locale falls back to the raw msgid" do
      Gettext.put_locale(LegalGettext, "zz")

      tab = Enum.find(Legal.settings_tabs(), &(&1.id == :admin_settings_legal))
      assert Tab.localized_label(tab) == tab.label
    end
  end
end
