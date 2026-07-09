# life.bqn — dimension-agnostic Game of Life engine.
#
# The whole thesis of the piece: ONE Life works for any rank d. Dimension is
# =𝕩 (the rank of the grid), not a rewrite. Verified against Conway patterns at
# d=2 (see test/test_life.bqn) before anything 4D is built on top.
#
# Grid is a boolean array of rank d, side length n (n⥊…⥊0). Toroidal on every
# axis (rotate wraps), so the hidden w-axis wraps too.

⟨Box, Neigh, Life, Run, Trajectory, AxisDom⟩⇐

# 𝕨=↕=𝕩 is the unit vector eₐ (1 on axis a, 0 elsewhere), so v⌽ and (-v)⌽ are the
# ±1 toroidal shifts along axis a. These two build every neighbour sum.
Face ← {v←𝕨=↕=𝕩 ⋄ (v⌽𝕩)+(-v)⌽𝕩}   # the two ±1 hyperplanes along axis 𝕨, summed
Sum3 ← {𝕩+𝕨 Face 𝕩}               # 3-wide toroidal sum along axis 𝕨 (with centre)

# Toroidal Moore-box sum: the full 3×3×…×3 box factors into a length-3 sum along
# each axis, so it's Sum3 folded over every axis — ~3d shift-adds, not 3^d shifted
# copies (d=4: ~12 adds, not 81). The grid seeds the fold; ↕=𝕩 are its axes.
Box   ← {𝕩 Sum3´ ↕=𝕩}
Neigh ← Box-⊢                     # Moore neighbour count = box sum minus the centre

# One generation. 𝕨 ≡ ⟨survive-list, birth-list⟩ — lists of neighbour counts
# (Bays-style S/B). Lists, not scalars: n∊b needs rank ≥1 on the right.
Life ← {s‿b←𝕨 ⋄ n←Neigh 𝕩 ⋄ (n∊b)∨𝕩∧n∊s}

# Run k generations of rule r from grid 𝕩.                 𝕨 ≡ ⟨rule, k⟩
Run        ← {r‿k 𝕊 g: (r⊸Life)⍟k g}
# All k+1 states (initial + k gens) as a leading-axis stack of grids — used by the
# renderer (frame per state) and the search harness (population curve).  𝕨 ≡ ⟨rule, k⟩
Trajectory ← {r‿k 𝕊 g: (r⊸Life)⍟(↕k+1) g}

# Per-cell dominant axis (0..d-1): the axis whose two ±1 hyperplanes hold the most
# live neighbours (Moore box over the OTHER axes). Ties → lowest index. Computed in
# full d-space, so a brane voxel tagged with the hidden axis is one whose neighbours
# live mostly off-slice — the invisible fraction, coloured.
AxisDom ← {g←𝕩 ⋄ d←=g
  Marg ← {(𝕩 Face g) Sum3´ (𝕩≠↕d)/↕d}   # 𝕩 = axis: its faces, boxed over the rest
  m ← > Marg¨ ↕d                          # the d marginal counts, stacked on axis 0
  +˝ ∧` ¬ m = (≢m)⥊⌈˝m                     # per cell: index of the first axis at the max
}
