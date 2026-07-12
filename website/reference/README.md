# Design reference

Pixel-perfect target for the marketing site. Source of truth is the Claude Design **handoff
bundle** in `_handoff/nocturne-gym-app-design/` — read
`_handoff/nocturne-gym-app-design/project/BJJ Open Mat Landing.dc.html` and its design system
`.../project/_ds/nocturne-8bf90f58-.../styles.css`.

## Reference screenshots (gitignored)

- `ref-desktop.png` — 1280×900 viewport, full page
- `ref-mobile.png` — 390×844 viewport, full page

These are the pixel-diff targets used by `website/tests/visual.spec.ts`. They are **not
committed** (see `.gitignore`); regenerate them from the prototype when needed:

```bash
# 1. Serve the prototype (it uses a custom x-dc runtime in support.js + _ds_bundle.js)
cd website/reference/_handoff/nocturne-gym-app-design/project
python -m http.server 8899 --bind 127.0.0.1

# 2. In Playwright, open http://127.0.0.1:8899/BJJ%20Open%20Mat%20Landing.dc.html
#    resize to 1280x900 -> full-page screenshot -> ref-desktop.png
#    resize to 390x844  -> full-page screenshot -> ref-mobile.png
#    save both into website/reference/
```

The interactive phone demo loads in its default `home` screen; the Angular build must match
that default state on load for the diff to pass.
