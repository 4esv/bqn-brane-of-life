# life.bqn — dimension-agnostic Game of Life engine.
#
# The whole thesis of the piece: ONE Step works for any rank d. Dimension is
# =𝕩 (the rank of the grid), not a rewrite. Verified against Conway patterns at
# d=2 (see test/test_life.bqn) before anything 4D is built on top.
#
# Grid is a boolean array of rank d, side length n (n⥊…⥊0). Toroidal on every
# axis (rotate wraps), so the hidden w-axis wraps too.

⟨Box, Neigh, Life, Run, Trajectory, AxisDom⟩⇐

# Toroidal 3-wide box sum along every axis (the separable Moore-box).
# The Moore box sum factors: a length-3 sum along each axis, composed across all
# d axes, equals the full 3×3×…×3 box. That's ~3d shift-adds, not 3^d shifted
# copies — for d=4, ~12 adds instead of 81. F folds the grid across its axes;
# for axis a, v is a rotation vector (1 on axis a, 0 elsewhere) so v⌽ and (-v)⌽
# are the ±1 toroidal shifts along that axis.
Box ← {
  d ← =𝕩
  F ← {𝕤 ⋄ a←𝕨 ⋄ g←𝕩 ⋄ v←1⌾(a⊸⊑)(d⥊0) ⋄ (v⌽g)+g+(-v)⌽g}
  𝕩 F´ ↕d
}

# Moore neighbour count = the box sum with the centre cell removed.
Neigh ← {(Box 𝕩)-𝕩}

# One generation. 𝕨 ≡ ⟨survive-list, birth-list⟩ — lists of neighbour counts
# (Bays-style S/B). Lists, not scalars: n∊b needs rank ≥1 on the right.
Life ← {s‿b←𝕨 ⋄ n←Neigh 𝕩 ⋄ (n∊b)∨𝕩∧n∊s}

# Run k generations of rule r from grid 𝕩. 𝕨 ≡ ⟨rule, k⟩.
Run ← {r‿k 𝕊 g: (r⊸Life)⍟k g}

# All k+1 states (initial + k generations) as a leading-axis stack of grids.
# Used by the renderer (frame per state) and the search harness (population
# curve). 𝕨 ≡ ⟨rule, k⟩.
Trajectory ← {r‿k 𝕊 g: (r⊸Life)⍟(↕k+1) g}

# Per-cell dominant axis (0..d-1): the axis whose two ±1 hyperplanes hold the
# most live neighbours (Moore box over the OTHER axes). Ties → lowest index.
# Computed in full d-space, so a brane voxel tagged with the hidden axis is one
# whose neighbourhood lives mostly off-slice — the invisible fraction, coloured.
AxisDom ← {g←𝕩
  d    ← =g
  Vec  ← {a‿k: k⌾(a⊸⊑)(d⥊0)}                       # rotation vector: k on axis a
  Sum3 ← {a 𝕊 x: x + ((Vec a‿1)⌽x) + (Vec a‿¯1)⌽x} # 3-wide sum along axis a
  Marg ← {a←𝕩                                       # marginal neighbour count, axis a
    face ← ((Vec a‿1)⌽g) + (Vec a‿¯1)⌽g             # the two ±1 hyperplanes
    face Sum3´ (a≠↕d)/↕d                            # boxed over the other axes
  }
  m ← > Marg¨ ↕d                                    # d × (grid shape)
  {𝕩 ⊐ ⌈´𝕩}⎉1 (d∾↕d) ⍉ m                            # argmax over axes, per cell
}
