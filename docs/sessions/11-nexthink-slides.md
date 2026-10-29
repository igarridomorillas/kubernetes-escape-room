# Session 11 — Nexthink Meetup Slides

> **Date:** 2026-10-29  
> **Status:** 🔍 In review (human sign-off pending)  
> **Branch:** `feat/slides_nexthink`

---

## 🎯 Objectives

1. Add a Nexthink meetup variant of the deck (presenters, Nexthink and hiring slides, Halloween theme, progress bar) without losing the original workshop deck.
2. Share the workshop slides and speaker notes between both decks so content is edited once.
3. Align the speaker notes with the docs, the slides and the level scenarios.

## 📦 Deliverables

| File | Change |
|---|---|
| `docs/presentation/slides.md`, `style.css`, `global-bottom.vue` | Original deck: cover plus `src: ./shared/workshop.md`; theme and counter as on `main` (plus compact `.body.lift` spacing) |
| `docs/presentation/shared/workshop.md` | The 20 shared slides ("Today's route" to "Questions?") with the rewritten speaker notes |
| `docs/presentation/nexthink/slides.md` | Cover, presenters, Nexthink slide, shared slides, hiring slide with QR |
| `docs/presentation/nexthink/style.css` | Halloween theme, progress bar, `.body.lift`, PDF-safe overrides (`html.print`) |
| `docs/presentation/nexthink/global-bottom.vue` | Window-fixed progress bar (teleported to `body`) and `n/total` counter |
| `docs/presentation/nexthink/public/sre-hiring-qr.png` | Hiring QR code |
| `Makefile`, `package.json`, `.gitignore` | `slides-nexthink`, `slides-nexthink-export`, `dev:nexthink` / `build:nexthink` / `export:nexthink`, ignore rules for the new outputs |
| `README.md`, `AGENTS.md`, `docs/presentation/README.md`, `docs/design/plan.md` | Trees, commands, "Slide rules" learnings, Amendment 9 |

## 🧠 Learnings

1. **The entry's directory is the Slidev root.** `style.css`, `global-bottom.vue` and `public/` are read from the directory of the entry file, so a second entry in `nexthink/` gets its own theme and assets while `src:` pulls shared slides in from `../shared/`. `node_modules` is still found through the shared `package.json`.
2. **Shared notes must not hold absolute slide numbers.** The two decks number the same slide differently, so entry-specific timing lives in each cover note.
3. **PDF export renders glows as solid blocks.** `slidev export` prints `/print` with `screen` media. `text-shadow`, `box-shadow`, `mask-image` and `filter` came out as orange or green rectangles and a broken cobweb. Fixed elements teleported to `body` repeated on every page and added a blank 25th page. Fix: skip the bar when `location.pathname` contains `/print` and neutralise the effects under `html.print`.
4. **A bar inside the canvas disappears.** Letterboxed windows float it above the screen edge and small windows shrink it to about 4px. A `<Teleport to="body">` with `position: fixed` stays 6px at the window edge.
5. **The presenter view has its own bars.** Slidev draws a segmented slide strip on top and a clicks bar (`0/0`, empty when a deck has no v-click steps) below the slide. Hide ours with `useNav().isPresenter`. `$renderContext` is `none` in global layers, so it cannot tell previews from the main slide.
6. **`prefers-reduced-motion` hid the decorations on the author's Mac.** Reduce Motion was on, so effects disabled by that media query looked broken. Only flashing effects (lightning, title flicker) stay off for it.
7. **Less is more.** Fog, lightning, bats, a roaming ghost and a ghost AI with quips were built, then removed on review. The final theme is colours, glowing titles, cobweb, moon, pumpkin on the first and last slide, and the bar.
8. **Slide 12 overflowed in the original PDF.** The Do/Don't cards were clipped. The compact `.body.lift` rules (gap, card padding, list spacing) fix it in both decks.
9. **Speaker notes are instructor material.** They carry the root causes, the 504 to 502 progression, the verification-order trap and the unsafe shortcuts, so they must stay in sync with `docs/ai-exercises.md`, the `hints.md` files and `solution/`.
10. **No agent attribution.** Commits and PR descriptions carry no `Co-Authored-By` trailer or "Generated with" footer.

## ✅ Verification

- Both decks exported to PDF: 21 pages (original) and 24 pages (Nexthink); pages 1, 3, 7, 12, 14, 19, 21 and 24 were inspected, with no blank page, glow blocks or stray bar.
- `make check` passes; `npm run build:nexthink` builds.
- Not run (left unchecked): `make validate` shellcheck, a full `make slides-export` and `make slides-nexthink-export` through `make`, a live walkthrough of the presenter notes, scanning the QR code.

## Review checklist

- [ ] `make slides` shows the original deck (21 slides, blue theme)
- [ ] `make slides-nexthink` shows the Nexthink deck (24 slides), bar visible at several window sizes
- [ ] Slides 2, 3, 6, 9, 14 and 24 render without overflow
- [ ] Presenter notes match the scenarios and docs
- [ ] QR opens the right SRE position
