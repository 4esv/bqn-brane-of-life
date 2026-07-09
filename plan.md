# Plan — bqn-brane-of-life

## Context

The repo is a **seed** (`SPEC.md` + `README.md`, no code). The goal: an
n-dimensional Game of Life engine in BQN whose flagship output is a **3D brane
sliced from a 4D automaton** — you watch a 3D volume evolve while ~67.5% of what
drives it lives in a 4th dimension you can't see, so cells are born and die with
no visible cause. The piece *is* that number made visible.

The spec explicitly asks the planning agent (me) to produce `plan.md`, rank the
hard problems, resolve the open questions, and **prove d=2 correctness before
building anything 4D**. This file is that plan; on approval, Phase 0 copies it
into the repo as `plan.md` (the spec's stated deliverable).

### Already de-risked this session (empirical, not speculation)

I built and ran the core seam in CBQN before writing this plan:

- **Separable neighbor sum works and is correct.** A 3-wide toroidal box sum
  folded over every axis, minus the centre, gives the Moore neighbor count. It
  reproduces Conway's blinker exactly (horizontal→vertical→horizontal) at d=2.
- **The engine is genuinely rank-polymorphic.** The *same unmodified* `Box` /
  `Neigh` / `Life` functions ran at d=2, d=3, and d=4 — dimension is `=𝕩`
  (rank), not a rewrite. This is the whole thesis of the engine, and it holds.
- **The verified core (keep this, it's tested):**
  ```bqn
  Box  ← {d←=𝕩 ⋄ F←{𝕤⋄a←𝕨⋄g←𝕩⋄v←1⌾(a⊸⊑)(d⥊0)⋄(v⌽g)+g+(-v)⌽g} ⋄ 𝕩 F´ ↕d}
  Neigh← {(Box 𝕩)-𝕩}
  Life ← {s‿b←𝕨 ⋄ n←Neigh 𝕩 ⋄ (n∊b)∨𝕩∧n∊s}   # 𝕨 = ⟨survive-list, birth-list⟩
  ```
- **Impl note found the hard way:** survive/birth must be **lists** (rank ≥1);
  `n∊b` errors if `b` is a scalar. Rule `⟨5‿6‿7,⟨6⟩⟩`, not `⟨5‿6‿7,6⟩`.
- Both arbitrary d=4 test rules collapsed to population 0 in one step — the
  central risk in the flesh: **finding a *living, sparse* 4D rule is the real
  work, not the engine.**

### Environment (verified)

- CBQN at `/usr/local/bin/bqn` (also `BQN`), built with FFI. Pure BQN is fine at
  n=32 (sub-10ms/step per spec) — **no C/FFI needed**; escape hatch stays open.
- `ffmpeg` ✅ and ImageMagick (`magick`/`convert`) ✅.
- ⚠️ `pnmtopng` is **not** installed → convert PNM→PNG/video via ffmpeg or
  ImageMagick, not netpbm.
- `dlozeve/bqn-graphics` is **not** local. We emit PPM (P6) ourselves — trivial,
  zero BQN deps — and optionally vendor bqn-graphics' colormap tables only if we
  want its exact viridis/magma LUTs.
- BQNoise precedent (`~/Code/learning/BQNoise`) is **audio-only**: no image
  pipeline to copy, but its module idioms are worth mirroring (below).

### Decisions locked with Axel this session

- **Deliverable:** piece-with-a-tool-underneath. Reusable parameterized engine
  (`--d --n --rule --seed`), but the headline is **one curated flagship loop**.
- **w-seeding:** feed from hidden layers — action offset into `w≠0` so patterns
  drift into the visible `w=0` brane with no on-slice cause. Parameterized, this
  as default.
- **Rule search:** ship in-repo as `search.bqn`; it logs top rules to `rules.md`.

## Idioms to mirror from BQNoise

- Run as `bqn file.bqn`; **no shebang**; params via `•args`.
- **Shared-options namespace** threaded via `•args` + a `load.bqn` importer, so
  every module sees one config instance: `o ← ≠◶⟨•Import∘"options.bqn", ⊑⟩ •args`.
- Top-of-file **export lists** `⟨Name, Name2⟩⇐`.
- File I/O via **`•FBytes`** (monadic read / dyadic `path •FBytes bytes` write),
  output located with **`•wdpath`** so paths are CWD-relative not module-relative.
- Pure-BQN first; any optional native path guarded with `⎊` fallback.

## Module layout (new files in repo root unless noted)

| File | Role |
|---|---|
| `life.bqn` | Engine: `Box`, `Neigh`, `Life` (verified). Rank-polymorphic. Exports. |
| `seed.bqn` | 4D initial conditions: 3D pattern thickened/offset along `w`, plus noise in hidden layers; named seeds (glider, random, thickened). |
| `render.bqn` | Slice `w=0`; isometric voxel splat; painter's algorithm; bounding-box wireframe; depth shading → RGB raster. |
| `ppm.bqn` | Minimal P6 writer (`"P6\n{w} {h}\n255\n"` + RGB bytes) + colormap LUT (viridis/magma; inline table). |
| `search.bqn` | Rule-search harness → scores → `rules.md`. |
| `brane.bqn` | **Main entry.** Parse `•args`, seed, step N times, render each frame to `frames/%04d.ppm`. |
| `options.bqn`, `load.bqn` | Shared config (n, d, rule, seed params, canvas px, palette) + loader. |
| `makefile` | Targets: `frames` (run bqn), `video`/`gif` (ffmpeg), `hero`, `test`. |
| `test/test_life.bqn` | Conway correctness at d=2 — **gate before any 4D trust.** |
| `plan.md` | This plan, copied in (Phase 0). |

## Hard problems — ranked

1. **Finding a living, sparse 4D rule (highest risk).** Conway B3/S23 dies in 4D
   (80-cell neighborhood). This is *both* hard problem #1 (survival) and #2
   (density=visibility) from the spec — they're the same search with two
   constraints. Owned by Phase 2 / `search.bqn`. Score = persists + doesn't
   explode + churns + **low density** (sparse = translucent = you see interior
   churn, the whole point). Seed the search with Bays-style rules, then random
   sweep. This is the make-or-break; everything downstream is comparatively safe.
2. **Making a 3D cube read from a fixed 2D iso view.** Solved by decision but
   needs care: bounding-box wireframe (always drawn, so the "stage" reads even at
   low density) + depth shading along the view diagonal. Iso alone is
   depth-ambiguous.
3. **Authoring an interesting 4D seed by hand** (Phase 1/`seed.bqn`). Approach:
   3D pattern thickened + offset along `w`, hidden-layer noise. Locked default:
   feed from hidden layers.
4. **Performance.** Lowest risk — separable sum + n=32 is sub-10ms/step, and we
   batch-render offline. Push to 48–64 only after a good sparse rule is found.

## Phases & acceptance criteria

**Phase 0 — repo hygiene.** Copy this plan to `plan.md`. Add `makefile`,
`options.bqn`, `load.bqn` skeleton. Fix the `.gitignore` trap: `*.gif`/`*.png`
are globally ignored, so the curated hero asset has no home — add a negation
(`!assets/hero.gif`) or an un-ignored `assets/`/`docs/` dir for the one committed
loop. *Accept:* `bqn -e '1+1'` runs; repo builds nothing yet but layout exists.

**Phase 1 — n-D engine + correctness gate.** Finalize `life.bqn` from the
verified core. Write `test/test_life.bqn` **first** (TDD): d=2 blinker (period 2),
glider (translates +1,+1 after 4 steps), block (still life), and a population
check. *Accept:* all d=2 tests pass; d=3/d=4 steps run without error and conserve
shape. **No 4D work proceeds until this gate is green.**

**Phase 2 — rule search.** `search.bqn`: given d, n, seeds, and a rule candidate
set, run N steps and score for non-trivial persistence + low density. Sweep
Bays-style candidates first, then random survive/birth sets. Log ranked results
to `rules.md`. *Accept:* at least one d=4 rule that (a) survives ≥100 steps,
(b) keeps live density in a target band (roughly 2–15% so the cube is
translucent), (c) shows churn (per-step change > 0). If none is good enough,
trigger the spec's fallback: alpha-accumulate voxels instead of opaque splat.

**Phase 3 — slice + render.** `render.bqn` + `ppm.bqn`:
- Slice the `w=0` 3-brane: `brane ← w0 ⊏ grid` along the w axis.
- **Iso projection** (fixed, parallel — no camera): for voxel `(x,y,z)`,
  `sx = (x−z)·cos30`, `sy = (x+z)·sin30 − y`, scaled by voxel pitch, centred on
  canvas. **Depth key** `x+y+z`; draw ascending (far→near) = painter's algorithm.
- **Voxel stamp:** precompute one filled hexagon mask at voxel pitch, reuse for
  every live voxel; write it into the raster in draw order (later overwrites =
  occlusion).
- **Depth shade:** normalize depth → colormap LUT (farther = darker/cooler).
- **Bounding box:** project the 8 cube corners, draw 12 edges by point-sampling.
- Emit `H×W×3` → PPM bytes via `ppm.bqn` → `frames/%04d.ppm`.
*Accept:* a single rendered frame of a hand-placed 3D shape (e.g. a diagonal bar)
plainly reads as voxels inside a cube — hexagonal splats, visible wireframe,
front occluding back. Verify by eye via the Chrome extension / an image viewer.

**Phase 4 — the invisible (the piece).** Use a rule from `rules.md` + a
feed-from-hidden-layers 4D seed. Batch-render a few hundred frames at n=32,
assemble a seamless loop (`makefile` → ffmpeg → mp4 + palettegen gif). Curate
until the loop is hypnotic and the "uncaused" births/deaths read. Rewrite
`README.md` around the 67.5% thesis with the hero loop as caption. *Accept:* a
committed `assets/hero.gif` + README that states the invisible fraction and shows
one seed evolving; loop is visually seamless.

## Verification strategy

- **Unit (engine):** `test/test_life.bqn` — Conway patterns at d=2, run via
  `make test`. This is the correctness backbone; it must stay green.
- **Search:** eyeball `rules.md`; sanity-check the chosen rule's population curve
  (should be bounded, non-zero, churning).
- **Render:** render one frame of a known shape and inspect it visually (Chrome
  extension screenshot or open the PNG); confirm hexagonal voxels, wireframe,
  depth occlusion, translucency.
- **End-to-end:** `make hero` from clean → produces the loop; watch it for
  seamlessness and the "unaccountable causation" effect.

## Flagged for Axel (non-blocking; sensible defaults chosen)

- **CLI rule notation:** I'll use `S5-7/B6` (Bays-style survive/birth, ranges ok)
  parsed into the internal `⟨survive-list, birth-list⟩`. Say if you want a
  different surface syntax.
- **Colormap:** default viridis for voxels (cool interior), warm accent for the
  wireframe. Easily swapped.
- **Canvas:** 800px default per spec ("plainly legible" at n=32).
