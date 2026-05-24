# Spec: Server-side gate for consent widget visibility

## Problem

Поточна реалізація ховає cookie consent віджет для авторизованих користувачів **з клієнта**:

1. Сервер рендерить `#pk-consent-root` завжди (незалежно від auth).
2. Іконка має `opacity-0` щоб не мигала.
3. JS робить запит `GET /phoenix_kit/api/consent_config` → отримує `should_show: false` → видаляє DOM-елемент.
4. Контролер ставить `Cache-Control: private, max-age=0` коли `hide_for_authenticated=true`.

Це працює, але:

- **Flash risk**: іконка рендериться і тримається на `opacity-0` до завершення API-запиту. Будь-який збій JS → іконка видима авторизованому.
- **Зайвий network round-trip** на кожній сторінці для авторизованого користувача.
- **Зайва JS-логіка**: `should_show`, `PhoenixKitConsent.initialized` guard, очищення DOM, reset Google Consent Mode.
- **Не DRY**: auth-перевірка дублюється — і на сервері (контролер), і на клієнті (`should_show`).

Правильне місце для цього рішення — server-side у самому компоненті.

## Goal

Компонент `cookie_consent/1` сам приймає рішення рендерити чи ні, на основі переданого scope. Клієнт не бере участь в auth-логіці.

## Design

### Компонент `cookie_consent/1`

Додати attr:

```elixir
attr :phoenix_kit_current_scope, :any,
  default: nil,
  doc: "PhoenixKit scope for auth-based visibility check"
```

На початку функції:

```elixir
def cookie_consent(assigns) do
  if should_hide_for_user?(assigns[:phoenix_kit_current_scope]) do
    ~H""
  else
    # ...existing render...
  end
end

defp should_hide_for_user?(scope) do
  PhoenixKit.Users.Auth.Scope.authenticated?(scope) and
    PhoenixKit.Modules.Legal.hide_for_authenticated?()
end
```

Коли компонент повертає `~H""`:
- Немає `#pk-consent-root` → хук не рендериться.
- Немає іконки → не треба `opacity-0`.
- JS `DOMContentLoaded` handler не знаходить елемент → `injectWidget()` fallback виконується **тільки якщо config.enabled**. Треба пересвідчитись, що цей шлях не ін'єктить віджет для авторизованих (див. JS-зміни нижче).

### Parent-app integration

У документації (README, `print_next_steps/0`) приклад виклику:

```heex
<PhoenixKit.Modules.Legal.CookieConsent.cookie_consent
  frameworks={["gdpr"]}
  consent_mode="strict"
  phoenix_kit_current_scope={@phoenix_kit_current_scope}
/>
```

Scope assign доступний у parent-apps через `PhoenixKitWeb.Integration` pipeline (вже використовується в admin layout, `root.html.heex`).

### JavaScript (`priv/static/assets/phoenix_kit_consent.js`)

Спрощуємо:

1. **Видалити** `should_show` handling з `fetchConfigAndInit()` — сервер більше не надсилає це поле (або надсилає `true` завжди, якщо рендериться).
2. **Видалити** виклик `fetchConfigAndInit()` з `DOMContentLoaded` auto-init. Якщо сервер не рендерив елемент — нічого не робимо.
3. **Залишити** `initFromElement()` на server-rendered `#pk-consent-root`.
4. **Залишити** `PhoenixKitConsent.initialized` guard для race LiveView-hook vs DOMContentLoaded.
5. **Залишити** `injectWidget()` як явний API `window.PhoenixKitConsent.init(config)` для мануального виклику (документований шлях, не auto).

Auto-init логіка `DOMContentLoaded` стає:

```javascript
document.addEventListener("DOMContentLoaded", function () {
  if (PhoenixKitConsent.initialized) return;
  var root = document.getElementById("pk-consent-root");
  if (root) initFromElement(root);
});
```

### Controller (`consent_config_controller.ex`)

Два варіанти:

**(A) Залишити як є** — корисно для мануальної ін'єкції через `window.PhoenixKitConsent.init()` в сторонніх контекстах. Просто ніхто з auto-init більше його не викликає.

**(B) Видалити** `should_show`, `is_authenticated`, auth-plug. API стає суто "віддай конфіг віджета". Sane default — API public, без auth awareness.

Рекомендую **(B)**: якщо auth-рішення приймається на сервері при рендері компонента, API не має жодного auth-контексту. Простіше.

### `cookie_consent.ex` cleanup

- Видалити `"transition-opacity duration-300 opacity-0"` з класів іконки (коміт `29dac21`).
- Іконка рендериться одразу видимою. Жодного flash не буде, бо auth-користувачі взагалі не отримають HTML іконки.

### `legal.ex` cleanup

- Прибрати `hide_for_authenticated` з `get_consent_widget_config/0` (якщо обрали варіант B для контролера) — значення більше нікому не потрібне на клієнті.
- `hide_for_authenticated?/0` сам — лишається, його використовує компонент.
- Default `true` — лишається (дефолтне значення відповідає дизайну "в адмін-панелі не показувати").

### Settings UI

Без змін. Користувач все ще бачить чекбокс "Hide for authenticated users" в `/phoenix_kit/admin/legal/settings`. Тепер цей прапор читається сервером при рендері компонента.

## Out of scope

- Per-route overrides (наприклад, "завжди показувати на `/billing`"). Якщо знадобиться — окрема спека.
- Зміна тайпу `hide_for_authenticated?/0` на per-scope rules.

## Acceptance criteria

1. Авторизований користувач на будь-якій сторінці (admin або public з logged-in сесією):
   - У DOM **немає** `#pk-consent-root`.
   - Немає мережевого запиту до `/phoenix_kit/api/consent_config`.
   - Немає іконки, банера, модалки.
2. Неавторизований користувач на публічній сторінці (перший візит):
   - Банер відображається одразу (фікс `63a132c` збережений).
   - Іконка відображається без `opacity-0` flash.
   - Layout банера коректний (фікс `0c76520` збережений).
3. Неавторизований користувач, який вже давав consent:
   - Банер схований, іконка видима для повторного виклику preferences.
4. Якщо parent-app не передає `phoenix_kit_current_scope` (наприклад, інтегрований без PhoenixKit auth):
   - `should_hide_for_user?/1` з `nil` scope → `false` → віджет рендериться як для анонімного. Backward-compatible.
5. Всі існуючі тести проходять. Додані нові тести на:
   - Компонент з `phoenix_kit_current_scope: authenticated_scope` + `hide_for_authenticated?=true` → порожній output.
   - Компонент з тим самим scope + `hide_for_authenticated?=false` → повний рендер.
   - Компонент з `nil` scope → повний рендер.

## Files to touch

- `lib/phoenix_kit_legal/web/cookie_consent.ex` — додати attr, early-return, прибрати `opacity-0`.
- `priv/static/assets/phoenix_kit_consent.js` — спростити auto-init, прибрати `should_show` handling.
- `lib/phoenix_kit_legal/web/consent_config_controller.ex` — (B) прибрати auth plug і `should_show`.
- `lib/phoenix_kit_legal/legal.ex` — прибрати `hide_for_authenticated` з widget_config map (опційно).
- `lib/mix/tasks/phoenix_kit_legal.install.ex` — оновити приклад у `print_next_steps/0`, додати `phoenix_kit_current_scope={@phoenix_kit_current_scope}`.
- `README.md` — оновити приклад інтеграції.
- `test/` — додати тести на early-return компонента, оновити тести контролера.

## Migration notes for parent apps

Після оновлення бібліотеки parent-apps мають додати `phoenix_kit_current_scope={@phoenix_kit_current_scope}` до виклику `<.cookie_consent ...>`. Без цього поведінка буде як раніше (віджет видимий для всіх) — тобто **breaking change тільки щодо наміру ховати від авторизованих**, а не щодо загальної роботи.

`phoenix_kit_install` task оновити так, щоб `print_next_steps/0` підказував додати цей attr.
