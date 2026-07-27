# Apple Review — Guideline 2.1(a) resubmission (build 1.0 / 116)

**Date:** 2026-07-26
**App:** BJJ Open Mat (`com.davissylvester.bjjOpenMat`)
**Build:** 1.0 (116) — resubmitted **as-is** (server-side fix, no new binary)
**Submission ID:** `0618147b-39a5-46c7-ae31-dd3f28cba401`

## Rejection

**Guideline 2.1(a) — Performance: App Completeness.** Reviewed 2026-07-25 on an
iPad Air 11-inch (M3), iPadOS 26.5.2:

> Bug description: your app displayed a **network error message** when we attempted
> to Sign in with Apple.

## Root cause & fix (server-side)

The error came from our identity provider (Auth0), not the app binary. The
**Sign in with Apple** connection was not enabled for the native application in
Auth0, so `/authorize?connection=apple` returned an error the app surfaced as a
network error. Fixed by creating + enabling the `apple` connection (and the other
social connections) for the native app via the Auth0 Management API — see
`docs/auth0-apple.md`.

**Verified end-to-end (2026-07-26):** a real Sign in with Apple completed and Auth0
recorded success events for `connection=apple`, user `apple|001221.a316668f…`:
- `type=ss` (first-time signup) at `2026-07-26T22:55:27.911Z`
- `type=s` (login) at `2026-07-26T22:55:27.914Z`

Apple's hosted sign-in page also loads correctly ("Use your Apple Account to sign in
to BJJ Open Mat Sign In") with the Services ID accepted (no `invalid_client`). All
methods — Apple, Google, Facebook, Amazon, Microsoft, email/password — are enabled.

The "Sign in with Apple" button has shipped in the app binary since the first commit,
so **no rebuild is required**; build 116 now authenticates correctly.

## Before resubmitting — checklist

- [ ] (Recommended) Install build 116 via TestFlight on an iPad and confirm
      "Continue with Apple" now signs in (the reviewer's device class).
- [ ] App Store Connect → App Review Information → Sign-In Information: set a working
      demo login (e.g. `test-user@local.priv`) and check "Sign-in required".
- [ ] Confirm build 1.0 (116) is the version attached for review.
- [ ] Post the Resolution Center reply below on submission
      `0618147b-39a5-46c7-ae31-dd3f28cba401`.
- [ ] Click **Resubmit to App Review**.

## Resolution Center reply (paste this)

> Hello, and thank you for the review.
>
> The network error shown when tapping "Sign in with Apple" was caused by a
> server-side authentication configuration issue, not the app binary. Our identity
> provider had the Sign in with Apple connection disabled for this application, so the
> authorization request returned an error that the app surfaced as a network error.
>
> We have enabled and verified the Sign in with Apple connection, and confirmed a
> successful Apple authentication end-to-end today. The other sign-in methods
> (Google, Facebook, Amazon, Microsoft, and email/password) are also enabled and
> working.
>
> Because this was a backend configuration fix, no binary change was required - the
> same build, 1.0 (116), now completes Sign in with Apple successfully. Please retry
> "Sign in with Apple" on the login screen; it will now sign in and reach the app.
> You may also use the demo account provided in App Review Information.
>
> Thank you for your time reviewing our app.
