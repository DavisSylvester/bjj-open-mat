# Marketing Assets

Rendered graphics for social posts. Source HTML lives beside each PNG; regenerate by serving the
folder (`python -m http.server 8099`) and screenshotting at the target size with Playwright.

Fonts embedded locally in `fonts/` (Plus Jakarta Sans) so renders are on-brand offline.

Every audience has every format. Two audiences (**practitioner**, **gym-owner**) × four ratios.

| Format | Size / ratio | Practitioner | Gym-owner |
|---|---|---|---|
| Square | 1080×1080 · 1:1 | `fb-post-openmat.png` | `fb-post-gym.png` |
| Portrait | 1080×1350 · 4:5 | `fb-post-portrait.png` | `fb-post-gym-portrait.png` |
| Landscape | 1200×630 · 1.91:1 | `fb-banner.png` | `fb-banner-gym.png` |
| Vertical | 1080×1920 · 9:16 | `story-vertical.png` | `story-vertical-gym.png` |

Each PNG has a matching `.html` source (practitioner: `fb-post.html`, `fb-post-portrait.html`,
`fb-banner.html`, `story-vertical.html`; gym adds the `-gym` suffix). Re-render any by serving the
folder and screenshotting at the target size.

## Which format for which platform

| Platform | Best format |
|---|---|
| **Facebook** feed / groups | Square or Portrait |
| **Facebook** link post / Page cover | Landscape |
| **Instagram** feed | Portrait (best reach) or Square |
| **Instagram** Stories / Reels cover | Vertical |
| **LinkedIn** | Landscape (or Square) |
| **Twitter / X** | Landscape |
| **TikTok** | Vertical as a cover **only** — TikTok is video-first; the real post is a filmed clip (see [`../founder-script-pack.md`](../founder-script-pack.md)) |

Use the **practitioner** set for general/consumer groups and the **gym-owner** set for
gym-owner / martial-arts-business groups.

For richer art beyond CSS (illustration, carousels, dark variants), see [`../claude-design-prompt.md`](../claude-design-prompt.md).

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
