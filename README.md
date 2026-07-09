# bqn-brane-of-life

An n-dimensional Game of Life engine in BQN. It runs Conway-style rules in 3D,
4D, or higher, and renders a lower-dimensional slice of the grid as an animated
loop. The default view is a 3D volume sliced from a 4D automaton.

Built to explore how Game of Life behaves above two dimensions. There is no
application beyond that.

![A 3D slice of a 4D automaton, coloured by neighbour axis](assets/hero.gif)

*3D slice of a 4D `S4/B4` automaton. 32³ voxels over 96 generations, coloured by
each cell's dominant neighbour axis.*

## Overview

Ordinary Game of Life is two-dimensional: a cell lives or dies according to its 8
neighbours. This generalises to any dimension `d`, where a cell has `3^d − 1`
neighbours and a rule is a set of neighbour counts for survival and for birth.
The engine runs that in arbitrary `d`, then renders a `k`-dimensional slice
(`k ≤ d`) so the result can be displayed.

Because the renderer shows only `k` of the `d` axes, the neighbours along the
hidden axes never appear on screen. The fraction of each cell's neighbourhood
that is off-screen is:

```
invisible = (3^d − 3^k) / (3^d − 1)
```

For the default 3D view of a 4D grid that is `(81 − 27) / (81 − 1)`, or 67.5%.
Cells then appear and disappear with no visible cause, which is what makes the
higher-dimensional slices interesting to watch.

| d | Moore neighbours | invisible for a 3D slice |
|---|---|---|
| 3 | 26  | 0% (nothing hidden) |
| 4 | 80  | 67.5% |
| 5 | 242 | 89.3% |

## Requirements

- [CBQN](https://github.com/dzaima/CBQN), with `bqn` on your PATH
- `ffmpeg`, to assemble frames into video and gif

There are no other dependencies. The renderer is pure BQN and writes PPM frames;
ffmpeg is only used to stitch them into a loop.

## Usage

```sh
make test     # engine correctness gate (Conway patterns at d=2, rank checks at d=3/4)
make hero     # render the default loop to assets/hero.gif and out/brane.mp4
make search   # search for viable 4D rules and write rules.md
make clean
```

Or run the engine directly:

```sh
bqn brane.bqn k=3 d=4 n=32 rule=S4/B4 steps=200
```

The invisible fraction is printed on each run. Some combinations:

```sh
bqn brane.bqn k=2 d=2       # ordinary flat Life         (0% hidden)
bqn brane.bqn k=2 d=4       # a 2D window on a 4D grid    (90.0% hidden)
bqn brane.bqn k=3 d=4       # the default cube            (67.5% hidden)
bqn brane.bqn k=4 d=4 n=10  # 4D as a grid of cubes       (0% hidden)
bqn brane.bqn k=1 d=3       # a single line               (92.3% hidden)
```

## Render modes

The renderer chooses a mode from `k`, the visible dimension (`1 ≤ k ≤ 4`):

| k | mode |
|---|---|
| 1 | a line of cells |
| 2 | a flat grid (ordinary Game of Life) |
| 3 | an isometric voxel cube |
| 4 | a grid of cubes, one per position along the 4th visible axis |

Each cell is coloured by the axis most of its neighbours lie on. In a 4D run the
hidden axis is drawn in magenta, so cells being driven from off-screen are
visible as such.

![The four render modes at different (k, d), each labelled with its invisible fraction](assets/dimensions.png)

## Configuration

Options are passed as `key=value` arguments to `brane.bqn`:

| option | default | meaning |
|---|---|---|
| `k`     | `3`      | visible dimension, 1 to 4 |
| `d`     | `4`      | automaton dimension, at least `k` |
| `n`     | `32`     | grid side length |
| `rule`  | `S4/B4`  | survive/birth rule (see below) |
| `steps` | `240`    | generations to render |
| `seed`  | `42`     | RNG seed |
| `px`    | `800`    | canvas size in pixels |
| `wc`, `wh` | `1`, `1` | centre and half-width of the hidden-layer seed band |
| `out`   | `frames` | output directory for PPM frames |

The makefile exposes the same settings as uppercase variables, e.g.
`make hero K=4 D=4 N=10`.

## Rules

Rules use Carter Bays' survive/birth notation, with ranges allowed: `S4/B4`,
`S3-6/B3`, `S5-8/B9-10`. `S` lists the neighbour counts at which a live cell
survives, `B` the counts at which a dead cell is born.

Conway's `S2-3/B3` does not survive in 4D. With 80 neighbours instead of 8, a
random field overcrowds and dies within a few generations. `search.bqn` addresses
this by scoring random interval rules on a shared seed for survival, low density,
and sustained change, then writing a ranked table to [`rules.md`](rules.md). The
default `S4/B4` comes from that search: it holds a steady density near 8% with
high turnover, so the volume stays translucent and does not strobe.

## How it works

A neighbour count is the grid summed over every shift, which in an array language
is the same code at any rank. The sum is separable, one 3-wide sum along each axis
composed over all axes, so 4D costs about 12 shift-and-add passes rather than the
81 needed to build every shifted copy.

```bqn
Box  ← {d←=𝕩 ⋄ F←{𝕤⋄a←𝕨⋄g←𝕩⋄v←1⌾(a⊸⊑)(d⥊0)⋄(v⌽g)+g+(-v)⌽g} ⋄ 𝕩 F´ ↕d}
Neigh ← {(Box 𝕩)-𝕩}
Life ← {s‿b←𝕨 ⋄ n←Neigh 𝕩 ⋄ (n∊b)∨𝕩∧n∊s}   # 𝕨 = ⟨survive, birth⟩
```

Boundaries wrap on every axis, including the hidden ones. Dimension is read from
the grid's rank, so `d` is a parameter rather than a rewrite. Correctness is
pinned at d=2 against known Conway patterns before anything runs in 4D; see
`test/test_life.bqn`.

## Project structure

| file | role |
|---|---|
| `life.bqn`   | dimension-agnostic engine (`Box`, `Neigh`, `Life`, `Run`, `Trajectory`, `AxisDom`) |
| `seed.bqn`   | initial conditions (`Noise`, hidden-layer `Slab`) |
| `search.bqn` | rule search, writes `rules.md` |
| `render.bqn` | k-D brane to RGB raster (line, grid, cube, or small multiples) |
| `ppm.bqn`    | PPM (P6) writer |
| `brane.bqn`  | entry point: evolve, slice, render frames |
| `test/`      | correctness gate |
| `plan.md`, `SPEC.md` | build plan and original brief |

## References

- Carter Bays, on higher-dimensional Life rules and survive/birth notation.
- [`dlozeve/bqn-graphics`](https://github.com/dlozeve/bqn-graphics), a BQN
  array-to-PNM reference. This project emits PPM directly instead.
- [BQN](https://mlochbaum.github.io/BQN/) and CBQN. Media-pipeline conventions
  follow [BQNoise](https://github.com/4esv/BQNoise).
