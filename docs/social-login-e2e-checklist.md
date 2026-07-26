# Social Login — Manual E2E Checklist

Run after enabling a provider's Auth0 connection (`setup-social-connections.mts --commit` + `--verify` shows `native-enabled=true`).

## Launch (Android emulator)

```bash
# start an emulator first (or use a physical device with `-d <id>`)
cd apps/mobile && flutter run -d emulator-5554 \
  --dart-define-from-file=.env \
  --dart-define=API_BASE_URL=https://api.bjj-open-mat.dsylvester.io \
  -Pauth0Domain=dev-vhvwupdn45hk7gct.us.auth0.com
```

If `flutter run` fails to attach (known flaky on this project), build+install then launch via adb:
`flutter build apk --debug ...` → `adb install -r <apk>` → `adb shell am start -n com.davissylvester.bjjopenmat/.MainActivity`.

## Per-provider checklist

For each of Facebook / Amazon / Microsoft:

- [ ] Login screen shows the **Continue with `<provider>`** button.
- [ ] Tapping it opens the provider's **real consent screen** (not an Auth0 error page).
- [ ] Approving returns to the app (deep-link callback succeeds — no "can't open page").
- [ ] App lands on `/role-select` (first login) or home (returning user).
- [ ] Profile syncs: display name / avatar populated; email present where the provider returns it.
- [ ] Log out and back in works (no duplicate account / stuck state).

Record per provider: PASS/FAIL, whether email was returned, any consent-screen quirk.

## If a provider fails

1. Read the error shown on the login screen (`authState.error`).
2. Auth0 Dashboard → **Monitoring → Logs** — find the failed transaction; the `description` usually names the cause (bad redirect URI, invalid client secret, app not Live, scope).
3. Common causes: provider app still in Development/not Live (Facebook), redirect URI mismatch, wrong/expired client secret, connection not enabled for the native app.
4. If it's app-code (e.g. empty-email onboarding), fix on the branch and re-run.

## Providers

| Provider | Auth0 connection | Notes |
|---|---|---|
| Facebook | `facebook` | Own account works in Dev mode; public needs Live + email advanced access. |
| Amazon | `amazon` | — |
| Microsoft | `windowslive` | Personal (Outlook/Hotmail/Live) accounts. |
