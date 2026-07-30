# My Gym Tab — Design

**Date:** 2026-07-30
**App:** BJJ OPEN MAT (iOS, Apple ID `6787704999`)
**Status:** Approved

## Problem

A gym's community surfaces already exist — roster, schedule, forum, instructor
feedback — but every one of them sits three taps deep behind search → gym detail.
A user who trains at a gym has no direct way back to it, so the community features
built for them are effectively unreachable in daily use.

## What this builds

A **My Gym** tab in the bottom navigation that lands on a hub for the user's gym.

It replaces **Report**, which moves into the Profile settings card beside Account.
`kPracTabs` becomes `['home', 'search', 'mygym', 'profile']`, preserving the
existing 2 tabs + FAB + 2 tabs layout.

`apps/mobile/test/nav_tabs_test.dart` currently pins `kPracTabs.length == 4`,
`indexOf('profile') == 2`, and `last == 'report'`. Those assertions are updated
deliberately as part of this work — they are a specification of the tab order, not
incidental breakage.

## Which gym is "my gym"

Two independent notions of a home gym exist today and can disagree:

- `UserProfile.homeGymId` — set on the profile screen
- `GymMembership.isHome` — set from the My Gyms screen

They already diverge in practice: an account can show "Home gym: RM Elite Brazilian
Jiu-Jitsu" on the profile while My Gyms reports "No gym memberships yet."

**Resolution order:** `UserProfile.homeGymId`, falling back to the membership flagged
`isHome`. A single resolver provider owns this precedence so the rule lives in one
place and the divergence stays contained rather than spreading through the UI.

**This is a papering-over, not a fix.** The correct long-term change is to make
setting a profile home gym create or update a membership, so the two cannot diverge.
That is a data migration plus backend work and is deliberately out of scope here. It
is recorded in "Follow-up work" below so it is not silently forgotten.

## Hub contents

Four sections, all fed by endpoints that already exist. **No backend work.**

| Section | Content | Existing endpoint |
|---|---|---|
| Header | Gym name, verified badge, tap through to the full gym page | `GET /api/v1/gyms/:id` |
| Next up | Next scheduled class or open mat, with a check-in affordance | `GET /api/v1/gyms/:id/schedule` |
| Quick actions | Schedule, Roster, Forum, Instructor feedback | existing routes |
| Recent in the forum | Three newest questions, tapping into the forum screens | `GET /api/v1/gyms/:id/forum/questions` |

**"Next up" precedence.** Show the single soonest upcoming item by start time,
whether it is a class or an open mat — not one of each, and not a list. Ties break
toward the class, since a scheduled class is the more common commitment. If the
schedule endpoint returns no upcoming item, the section is omitted entirely rather
than showing an empty placeholder.

**Check-in affordance.** The section links into the existing check-in flow for that
occurrence. It does not introduce a new check-in path. If the item is not currently
checkinable (too far in the future, per existing rules), the section shows the item
without a check-in button rather than a disabled one — the Join-button lesson from
1.1, where a greyed control with no explanation read as broken.

"Next up" is the working half — the thing the user actually came to do. "Recent in
the forum" is the playing half, and the section most likely to bring someone back
daily.

**Deliberately excluded:** no new feeds, no notifications surface, no gym chat. Each
would be its own build. The hub earns its place by surfacing what already exists.

## Empty state

When neither a profile home gym nor an `isHome` membership exists, the tab shows a
short explanation of what My Gym is plus a button into gym search.

This path is the actual onboarding into a community, so it is designed rather than
treated as an error state. The tab is never hidden — a tab bar that changes shape
underneath the user is disorienting, and hiding it conceals the feature from exactly
the people who have not yet found a gym.

## Report relocation

Report moves to a `ListTile` in the Profile settings card, beside Account, following
the same pattern as the Favorites row added in 1.1.

**Accepted tradeoff.** Report is the path for flagging bad data and problem gyms.
Demoting it will reduce report volume. Two taps from Profile is judged acceptable
reachability for a rare utility action, but this is a deliberate product decision
with a real cost, not a neutral layout change. If report volume matters more than
gym-community access, the alternative is a fifth tab.

## Testing

- Resolver precedence: profile `homeGymId` wins; membership `isHome` used when the
  profile value is absent; null when neither exists.
- Empty state renders its call to action and routes into gym search.
- Each quick action routes to the correct existing screen.
- `nav_tabs_test.dart` updated to pin the new tab order and length.
- Report is reachable from Profile settings.

## Out of scope

- Unifying `homeGymId` and `isHome` (see Follow-up work).
- Any change to the gym detail screen, roster, schedule, forum, or instructor
  feedback screens themselves.
- New backend endpoints. If a section cannot be built from an existing endpoint, it
  is cut rather than expanded into backend work.
- Android-specific navigation changes.

## Follow-up work

1. **Unify home-gym state.** Setting a profile home gym should create or update a
   membership so `UserProfile.homeGymId` and `GymMembership.isHome` cannot diverge.
   Requires a backend change and a migration for existing divergent accounts.
2. **Monitor report volume** after Report is demoted. If it drops materially,
   reconsider the tab layout.

## Risks

**Divergent home-gym state.** The resolver makes the tab work today, but a user whose
profile home gym differs from their `isHome` membership will see the profile one,
which may not be where they actually train. Acceptable because the alternative —
showing an empty state to users who have set a home gym — is worse, and because the
follow-up removes the divergence at its source.

**Tab discoverability.** Users accustomed to Report in the fourth slot will tap My
Gym by muscle memory. Unavoidable with any tab change; mitigated by Report remaining
two taps away.
