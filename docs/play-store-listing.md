# Google Play Listing — BJJ Open Mat (com.davissylvester.bjjopenmat)

Compliant replacement listing after the 2026-07-14 Misleading Claims rejection.
Every claim below maps to a shipped, reachable feature. Do NOT add claims for
features that are not in the released build.

## Short description (max 80 chars)
```
Find BJJ open mats near you, RSVP, check in, and log your training.
```

## Full description (max 4,000 chars)
```
BJJ Open Mat is the fastest way to find a place to roll — wherever you are.

Open the app and it shows open mats near you using your location. Filter by
gi, no-gi, skill level, day, and distance (up to 100 miles), or search any
city or ZIP.

FIND A MAT
• See open mats near you the moment you open the app
• Search by GPS, city, or ZIP
• Filter by Gi / No-Gi, free sessions, skill level, and when you want to train
• View session details: time, day, fee, gym, and one-tap directions

SEE WHO'S GOING
• Tap "I'm going" to RSVP to a specific session
• See how many people are coming and who they are
• Check in when you arrive and log rounds, partners, and a review

YOUR TRAINING
• Session history built from your real check-ins
• Mats, gyms, rounds, and weekly streak at a glance
• Save favorite gyms for quick access

YOUR PROFILE
• Track your belt and stripes
• Set your IBJJF weight class (by gender and gi/no-gi)
• Save your home city and gym

FOR GYM OWNERS
• Post open mat sessions and keep them up to date
• See expected attendance from RSVPs alongside real check-ins
• Switch between practitioner and gym-owner views any time

Community-driven: anyone can submit an open mat, and gym owners verify their
sessions.

Grab your gi (or don't) and go find a roll.
```

## Resubmission checklist (Play Console)

1. **Ship the fixed build**: merge this branch, run the Mobile Release
   workflow (or push a release) so the new `.aab` lands on the `internal`
   track; promote to production review.
2. **Retake ALL en-US phone screenshots** from the fixed build with a real
   account that has real data — no placeholder art, no fabricated stats.
   Capture: Home/Near You, Search with filters, Open-mat detail with
   "I'm going", My Training (real history), Gym detail with Directions.
3. **Update Store listing**: Play Console → Grow → Store presence → Main
   store listing. Replace the description with the text above and upload the
   new screenshots. Check any custom/translated listings for the same claims.
4. **Resubmit**: Play Console → Publishing overview → send changes for review.
5. Do NOT appeal — the violation was accurate; the fix is the resubmission.

## Claim → feature audit (keep in sync)

| Claim | Feature | Code |
|---|---|---|
| Directions | Maps launch from gym/session detail | `features/gyms/data/directions.dart` |
| Log rounds/partners/review | Check-in form | `features/checkins/` |
| Session history + streak | My Training | `features/training/` |
| Favorite gyms | Favorites + gym-detail heart | `features/favorites/` |
| Who's going | RSVP + attendee grid | `features/open_mats/widgets/going_section.dart` |
| Real notifications inbox | Notifications screen | `features/notifications/` |
