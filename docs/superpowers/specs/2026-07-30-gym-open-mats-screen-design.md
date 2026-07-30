# Gym Open Mats Screen — Design

**Date:** 2026-07-30
**App:** BJJ OPEN MAT (iOS, Apple ID `6787704999`)
**Status:** Approved
**Depends on:** `feature/my-gym-tab` (the My Gym hub must exist to gain its tile)

## Problem

The gym detail screen renders an inline "Open Mats" list
(`gym_detail_screen.dart:228-245`) beneath five other sections and a permission-gated
link stack. Open mats are the app's core concept, yet they sit at the bottom of a long
scroll, and the section forces `gym_detail_screen.dart` to carry another `AsyncValue`
branch in a file already doing a lot.

## What this builds

**1. A dedicated screen** at `/gym/:id/open-mats` — `GymOpenMatsScreen`, nested under
the existing `gym/:id` route alongside `roster`, `schedule`, and `forum`.

It watches the existing `gymSessionsProvider` (`gym_sessions_provider.dart:30`,
`FutureProvider.family<List<OpenMat>, String>`) and renders the same `SessionRow` list
the inline section renders today, each tapping through to `/open-mat/${m.id}`.

**No backend work.** The provider and endpoint already exist.

| State | Behaviour |
|---|---|
| Loading | Centred spinner |
| Error | Message plus a retry that invalidates `gymSessionsProvider(gymId)` |
| Empty | "No open mats posted yet." plus a **Post an open mat** button to `/add-session` |
| Data | `SessionRow` per open mat, tapping to `/open-mat/${id}` |

**2. Gym detail** — delete the inline section and add an **Open Mats** row to the
existing link stack, following the same pattern as the Members and Class schedule rows
so it needs no new styling.

Placement: **directly above Members**, at the top of the stack. Open mats are what the
app is for; they should not sit below the administrative links.

**3. My Gym hub** — a fifth quick-action tile keyed `mygym-action-open-mats`, routing
to the same screen.

**The tile is ungated.** Unlike Forum (`assertActiveMember`) and Instructor Feedback
(`assertCanManageGym`), the open-mats endpoint has no membership requirement. Gating it
would repeat the defect the My Gym final review caught, where the UI offered actions the
API refuses. It is also the one community surface every user can reach, which is exactly
why it belongs on the hub.

## Known rough edge

The empty state's button opens `/add-session` **without the gym prefilled**.
`CreateSessionScreen` takes no constructor arguments (`create_session_screen.dart:14`),
so the user re-picks the gym they were just looking at.

Threading a gym through that form is a change to a screen this work does not otherwise
touch, so it is deliberately out of scope and recorded in "Follow-up work". Shipping the
button without prefill is still better than a dead-end empty state.

## Testing

- New screen renders a row per session when sessions exist.
- Empty state renders its message and the post button, and the button routes to
  `/add-session`.
- Error state renders a retry that invalidates the provider — not a blank screen.
- Gym detail no longer contains the inline Open Mats section, and does contain a row
  routing to `/gym/:id/open-mats`.
- The hub tile renders for a non-member (proving it is ungated) and routes correctly.
- Existing hub tile keys (`mygym-action-schedule`, `-roster`, `-forum`,
  `-instructor-feedback`) keep working.

## Out of scope

- Prefilling the gym in the add-session flow (see Follow-up work).
- Any change to `SessionRow`, the open-mat detail screen, or the add-session form.
- Filtering or sorting the open-mats list — it renders the provider's order, exactly as
  the inline section does today.
- Backend changes of any kind.

## Follow-up work

1. **Prefill the gym in the add-session flow** when it is entered from a gym-scoped
   screen, so a user posting an open mat from a gym's page does not re-select that gym.

## Risks

**Hub tile count.** The hub grid was designed with four tiles; a fifth may unbalance the
layout depending on how the grid wraps. Verify visually on the simulator — a 2×2 becoming
2+2+1 is the specific thing to look at.

**Discoverability regression.** Open mats currently appear inline without a tap. Moving
them behind a row means one more tap for anyone who scrolled to them. Mitigated by
placing the row at the top of the stack and adding the hub tile, which together make
them reachable in fewer taps than before from the common entry points.
