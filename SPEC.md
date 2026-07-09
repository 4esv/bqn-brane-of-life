# BQN-brane-of-life — Spec

> Seed brief. This is the input a planning agent consumes to produce `plan.md`.
> It captures decisions already made and the hard problems still open. It is
> **not** an implementation plan.

## What this is

An n-dimensional Game of Life engine written in BQN. The flagship configuration
is a **3-dimensional brane sliced from a 4-dimensional automaton**: you render a
3D volume that evolves, but a hidden 4th dimension drives much of what you see.
Patterns are born and die with no visible cause, because the cause is off-slice.

"brane" = the visible 3-brane embedded in 4-space.

## Thesis

In a d-dimensional Life, a cell's fate depends on its Moore neighborhood of
`3^d - 1` cells. If you only *render* a k-dimensional slice, the neighbors along
the `d - k` hidden axes are invisible. The share of each cell's fate driven by
the unseen is:

```
invisible_fraction = (3^d - 3^k) / (3^d - 1)
```

For the flagship (k=3 visible, d=4): `(81 - 27) / (81 - 1) = 54 / 80 =` **67.5%**.

So two-thirds of the brane's behavior comes from a dimension the viewer cannot
see. The piece *is* that number made visible. The README should show one seed
evolving, with the invisible fraction stated as the caption.

## The math

| d | Moore neighbors (3^d − 1) | invisible fraction for a 3D slice |
|---|---------------------------|-----------------------------------|
| 3 | 26                        | 0% (nothing hidden)               |
| 4 | 80                        | **67.5%** ← flagship              |
| 5 | 242                       | 89.3%                             |

Engine is dimension-agnostic; these are just parameter choices.

## Engine design (direction, not implementation)

The array-language reason Life is a one-liner: a neighbor count is the sum of the
board shifted in every direction. Canonical Dyalog APL:

```apl
life ← {⊃1 ⍵∨.∧3 4=+/,¯1 0 1∘.⊖¯1 0 1∘.⌽⊂⍵}
```

The two `∘.⊖` / `∘.⌽` outer products build the 3×3 = 9 toroidally-shifted copies.
**That is the seam for higher dimensions:** n axes of rotation → `3^n` shifted
copies, same shape of code. The engine should be rank-polymorphic so that `d` is
a *parameter*, not a rewrite — one `Step` function that works for any dimension.

Candidate BQN primitives for the planner/impl agent to pin down: rotate `⌽`,
rank `⎉`, cells `˘`, transpose `⍉`, and possibly window/stencil (`↕`, `⌜`) for the
neighbor sum. **Do not assume the exact glyph sequence from the APL above — BQN's
rotate-along-arbitrary-axis story differs; the impl agent should derive and test
it.** Toroidal (wrap-around) boundary is the default; the 4th axis wraps too.

**Use a separable neighbor sum, not `3^d` shifted copies.** The Moore box sum
factors: a length-3 sum along each axis, composed across all `d` axes, equals the
full `3×3×…×3` box. For d=4 that's ~12 shift-adds instead of 81 — roughly a 7×
win, and the difference between "n=64 is painful" and "n=64 is fine." Subtract the
centre cell to get the neighbor count. Keep the grid as a **boolean / i8 array**
(not f64) for memory.

## Render path (decided)

**Full BQN, fixed isometric view, 2D raster out — no external 3D renderer, no
orbit.** BQN emits the frames; `ffmpeg` assembles the loop.

- **Pipeline.** Build on `dlozeve/bqn-graphics` (BSD-3, vendorable): a BQN array →
  PNM via `pnm.bqn`, colour via `colormaps.bqn` (viridis/magma/…) and `colors.bqn`
  (HSV→RGB). Then `pnmtopng` (netpbm) / ImageMagick / `ffmpeg` for PNG + video.
  This is the only non-BQN dependency and it's just format conversion, not
  rendering.
- **Projection: isometric voxel splat.** Project each *live* voxel of the n³ brane
  to screen coords with a fixed isometric transform (parallel projection — no
  camera maths), then paint **back-to-front (painter's algorithm)** so front
  voxels occlude rear ones. Iso of a cube's outline is a regular hexagon with
  three visible faces — it reads unmistakably as a 3D cube. *Do not* use a
  density/max projection here: it collapses the volume to a flat square and throws
  away the cube.
- **Make the cube read from a fixed view:** (1) always draw the 12-line
  **bounding-box wireframe** so the "stage" is a visible cube even at low density;
  (2) **depth-shade** voxels along the view diagonal (darker/cooler = farther) —
  iso alone is depth-ambiguous, shading + the box frame resolve the 3D.
- **Only live voxels are drawn** (≤ n³, usually far fewer), so render cost is
  trivial next to the n⁴ automaton step. The step is always the bottleneck.

## Hard problems (rank these in plan.md)

1. **Rules don't survive the jump.** Conway's B3/S23 dies or explodes in 4D — the
   neighborhood is 80 cells, not 8. Each dimension needs its own survive/birth
   sweet spot. Carter Bays catalogued stable 3D/4D Life rules (digit-string
   survive/birth notation) in the '80s — start there, then search. A rule-search
   harness (seed → run N steps → score for non-trivial persistence) is probably
   its own milestone and its own nice visualization.
2. **Density = visibility (the real render risk).** The render path is decided
   (see above); what's *not* solved is that a "hot" rule fills the cube solid and
   you see only the outer shell. A sparse rule is translucent — you see interior
   churn through the gaps, which is the whole point. So visibility is a
   **rule-search constraint**, not a rendering one: prefer rules whose live
   density stays low. Fallback if no sparse rule is good enough: alpha-accumulate
   voxels instead of opaque splat.
3. **Slicing.** The slice is **fixed at `w = 0`** (fixed view, decided). Open sub-
   question left to the planner/Axel: seed placement along `w` relative to the
   visible slice — centre the action at `w = 0`, or offset it so the brane is fed
   by activity drifting in from hidden `w` layers.
4. **Seeding in 4D.** How do you author an interesting 4D initial condition by
   hand? Probably: seed a 3D pattern and thicken/randomize along `w`, or seed
   from noise and let the rule search find live rules.
5. **Performance & resolution.** A 4D grid is `n⁴` cells; the step (not the
   render) is the bottleneck. With the **separable neighbor sum** (~12 shift-adds,
   see Engine design), pure CBQN is comfortable well past the useful range:

   | n | 4D grid (n⁴) | 3D brane (n³) | ~per-step ops | verdict |
   |---|---|---|---|---|
   | 16 | 65 K | 4 K | ~1 M | trivial, near-interactive |
   | **32** | **1.05 M** | **33 K** | **~12 M** | **start here** |
   | 48 | 5.3 M | 110 K | ~64 M | fine offline |
   | 64 | 16.7 M | 262 K | ~200 M | heavy but OK offline |

   **Start at n=32:** a 32³ cube iso-splatted into a ~800px canvas is plainly
   legible with visible internal churn, and the step is sub-10ms in CBQN — you're
   batch-generating a few hundred frames for a loop, not running real-time, so
   there's headroom. Push to 48–64 once a good sparse rule is found and you want
   more filigree. The C-library escape hatch (precedent: BQNoise `lib.c` +
   FFTW/SoX) stays available but should not be needed at these sizes.

## Open questions for the planner

- Is the deliverable a *tool* (run any d, any rule) or a *piece* (one curated
  hypnotic loop)? The spec leans piece-with-a-tool-underneath.
- Seed placement along the hidden `w` axis relative to the `w=0` slice (see #3).
- Ship a rule-search sub-tool as part of the repo, or keep it in scratch?

*Resolved this session (don't relitigate):* full BQN · fixed isometric view ·
2D-raster iso voxel splat on `bqn-graphics` · slice fixed at `w=0` · separable
neighbor sum · start n=32. A rotatable three.js viewer is explicitly **out** for
v1 — orbiting the volume would let the viewer try to account for every
birth/death, which fights the "unaccountable causation" thesis.

## Suggested milestones (planner refines into `plan.md`)

- **Phase 0 — seed** (this doc, repo). ✅
- **Phase 1 — n-D engine.** `Step` for arbitrary d; prove correctness at d=2
  against known Conway patterns (glider, blinker) before trusting d=4.
- **Phase 2 — rule search.** Find survive/birth rules that live in 4D. Bays first.
- **Phase 3 — slice + render.** Extract the `w=0` brane each frame; iso voxel
  splat (bounding box + depth shading) → PNM → PNG via `bqn-graphics`.
- **Phase 4 — the invisible.** Curate the flagship loop; write the README around
  the 67.5% thesis; capture a hero GIF/video.

## Non-goals

- Not a general cellular-automata framework. Life-family rules, higher-D, sliced.
- Not a real-time interactive sim, and not a rotatable 3D viewer — fixed iso
  view only (see the thesis note under Open questions). three.js is reserved for
  a possible post-v1 "interactive" phase, nothing sooner.
- Not chasing pure BQN purity at the cost of a working piece — C escape hatch is fine.

## References

- Dyalog APL Life one-liner (above) — the array-language idiom to generalize.
- Carter Bays — higher-dimensional Life rules and their survive/birth notation.
- BQN docs (mlochbaum/BQN) + CBQN (already installed; used by your BQNoise).
- **`dlozeve/bqn-graphics`** (BSD-3) — the decided render base: BQN array → PNM
  (`pnm.bqn`), colormaps + HSV→RGB. Vendor it or use as reference.
- Your own `~/Code/learning/BQNoise` — precedent for CBQN + C-lib bindings.

## Note to the planning agent

Per Axel's convention, produce a `plan.md` (path is unknown and branching, so it
warrants one). Rank the hard problems, resolve the open questions or flag them
for Axel, and lay out the phases above with real acceptance criteria. Prove d=2
correctness before building anything 4D on top of an unverified `Step`.
