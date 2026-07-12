# Marketing Assets

Rendered graphics for social posts. Source HTML lives beside each PNG; regenerate by serving the
folder (`python -m http.server 8099`) and screenshotting at the target size with Playwright.

Fonts embedded locally in `fonts/` (Plus Jakarta Sans) so renders are on-brand offline.

| File | Size | Use | Source |
|---|---|---|---|
| `fb-post-openmat.png` | 1080×1080 | Practitioner FB group / IG feed post | `fb-post.html` |
| `fb-post-gym.png` | 1080×1080 | Gym-owner FB group / IG post (gold-forward) | `fb-post-gym.html` |
| `fb-banner.png` | 1200×630 | Link preview / FB Page cover (landscape) | `fb-banner.html` |

For richer art beyond CSS, see [`../claude-design-prompt.md`](../claude-design-prompt.md).

## Paired captions

**Practitioner** (`fb-post-openmat.png` / `fb-banner.png`) — from [`../initial-launch-kit.md`](../initial-launch-kit.md);
tweak the first line per group. **Post from your personal profile, one group at a time, follow
each group's self-promo rules:**

> Fellow grapplers 🥋 I built a free app to find open mats anywhere — filter gi/no-gi, see who's
> going, and tap "I'm going." It's in beta and I'm looking for founding testers + gyms who want
> their open mat on the map (free). Drop your city below and I'll make sure it's covered. Oss.
>
> 👉 bjj-open-mat.dsylvester.io

**Gym owner** (`fb-post-gym.png`) — for gym-owner / martial-arts-business groups:

> Coaches & gym owners 🥋 I built a free app that puts your open mat on the map — travelers and
> locals find you, RSVP, and show up, and you verify your own sessions and see expected attendance.
> Zero cost. First 100 gyms get a Founding Gym badge + a spotlight. Comment your gym + city and
> I'll get you listed. Oss.
>
> 👉 bjj-open-mat.dsylvester.io

⚠️ Do **not** schedule or mass-post into groups. This is manual, human, and rules-checked each time
(see [`../marketing-plan.md`](../marketing-plan.md) §4).
