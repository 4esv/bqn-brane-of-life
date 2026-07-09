# bqn-brane-of-life

An n-dimensional Game of Life in BQN. It runs Conway-style rules in 4D (or 3D,
or 5D) and renders a lower-dimensional slice of the grid — usually a 3D volume
cut out of a 4D automaton.

I wanted to see what Game of Life looks like above two dimensions. That is the
entire reason it exists. There is no practical use. I did check.

![A 3D slice of a 4D automaton, coloured by neighbour axis](assets/hero.gif)

*3D slice of a 4D `S4/B4` automaton. 32³ voxels, 96 generations, coloured by
which axis each cell's neighbours mostly sit on.*

## The one number worth knowing

A cell's fate depends on its `3^d − 1` Moore neighbours. Render only `k` of the
`d` dimensions and the neighbours along the dropped axes are off-screen:

```
invisible = (3^d − 3^k) / (3^d − 1)
```

For a 3D view of a 4D grid that's `(81 − 27)/(81 − 1) =` **67.5%**. So most of
what moves the visible cells is happening where you can't see it, and things
appear and vanish for no on-screen reason. It is not profound. It looks cool.
That was enough for me.

| d | Moore neighbours | invisible for a 3D slice |
|---|---|---|
| 3 | 26  | 0% (nothing hidden) |
| 4 | 80  | **67.5%** |
| 5 | 242 | 89.3% |

## Features, and why you would not use them

**Any dimension into any dimension.** `k` visible, `d` total, `1 ≤ k ≤ 4`, `k ≤ d`.
The renderer picks a mode from `k`:

- `k=1` → a line of cells
- `k=2` → a flat grid (i.e. ordinary Game of Life)
- `k=3` → an isometric cube
- `k=4` → a grid of cubes, one per position along the 4th visible axis

![Four render modes at different (k,d), each labelled with its invisible fraction](assets/dimensions.png)

**A rule search.** Conway's B3/S23 dies on contact with 4D (80 neighbours instead
of 8, everything overcrowds and starves), so `search.bqn` brute-forces rules that
survive, stay sparse, and keep moving, and dumps a leaderboard into
[`rules.md`](rules.md).

**Colouring by dominant neighbour axis.** Each cell is tinted by the axis most of
its neighbours lie on. In a 4D run the hidden axis gets magenta, so you can watch
cells being shoved around by a dimension you aren't drawing. Mostly it's prettier.

**A renderer written entirely in BQN.** Isometric splat, painter's algorithm as a
vectorised z-buffer, depth shading, a bounding-box wireframe. It emits PPM frames
and `ffmpeg` stitches them. No 3D engine, no camera, no dependencies past ffmpeg.

## Run it

Needs [CBQN](https://github.com/dzaima/CBQN) (`bqn` on PATH) and `ffmpeg`.

```sh
make test     # engine correctness gate (Conway patterns at d=2, rank check at d=3/4)
make hero     # render the default loop → assets/hero.gif + out/brane.mp4
make search   # look for living 4D rules → rules.md
make clean
```

Or drive it directly:

```sh
bqn brane.bqn k=2 d=2      # ordinary flat Life        (0% hidden)
bqn brane.bqn k=2 d=4      # 2D window on a 4D grid     (90.0% hidden)
bqn brane.bqn k=3 d=4      # the default 3D-of-4D cube  (67.5% hidden)
bqn brane.bqn k=4 d=4 n=10 # 4D as a grid of cubes      (0% hidden)
bqn brane.bqn k=1 d=3      # a single line              (92.3% hidden)
```

Full knobs: `k d n rule seed steps px wc wh out`. Rules use Bays survive/birth
notation with ranges: `S4/B4`, `S3-6/B3`, `S5-8/B9-10`. The invisible fraction
prints on every run.

## How it works

A neighbour count is the grid summed over every shift. In an array language that
is the same code at any rank, which is the only reason writing this in n
dimensions was not miserable. The sum is separable — a 3-wide sum along each axis,
composed over all axes — so 4D costs ~12 shift-adds instead of the 81 you'd get
from building every shifted copy.

```bqn
Box  ← {d←=𝕩 ⋄ F←{𝕤⋄a←𝕨⋄g←𝕩⋄v←1⌾(a⊸⊑)(d⥊0)⋄(v⌽g)+g+(-v)⌽g} ⋄ 𝕩 F´ ↕d}
Neigh ← {(Box 𝕩)-𝕩}
Life ← {s‿b←𝕨 ⋄ n←Neigh 𝕩 ⋄ (n∊b)∨𝕩∧n∊s}   # 𝕨 = ⟨survive, birth⟩
```

Boundaries wrap on every axis, hidden ones included. Dimension is read off the
grid's rank, so `d` is a parameter, never a rewrite.

## Design notes

- **Default rule `S4/B4`.** From the search: it holds a steady ~8% density with
  high turnover, so the cube stays see-through and doesn't strobe. The `B3` family
  works too but flickers with a period-2 parity beat.
- **Seeding.** The default drops noise into the hidden layers rather than the
  visible slice, so the cube is fed from off-screen. `wc`/`wh` move the band.
- **Fixed view, no orbit.** Partly less work, partly because a locked camera is
  what makes the off-screen churn read as strange rather than "oh, it's round the
  back."

## Layout

| file | role |
|---|---|
| `life.bqn`   | dimension-agnostic engine (`Box`, `Neigh`, `Life`, `Run`, `Trajectory`, `AxisDom`) |
| `seed.bqn`   | initial conditions (`Noise`, hidden-layer `Slab`) |
| `search.bqn` | rule search → `rules.md` |
| `render.bqn` | k-D brane → RGB raster (line / grid / iso cube / small multiples) |
| `ppm.bqn`    | PPM (P6) writer |
| `brane.bqn`  | main: evolve, slice, render |
| `test/`      | Conway correctness gate |
| `plan.md` · `SPEC.md` | how it got built, and the original brief |

## References

- Carter Bays — higher-dimensional Life rules and the survive/birth notation.
- [`dlozeve/bqn-graphics`](https://github.com/dlozeve/bqn-graphics) — render
  reference (BQN array → PNM). This repo emits PPM directly instead.
- [BQN](https://mlochbaum.github.io/BQN/) · CBQN. Media-pipeline habits come from
  my own [BQNoise](https://github.com/4esv/BQNoise).
