# seed.bqn — initial conditions for the automaton.
#
# All seeds return a boolean grid of rank d, side n (shape d⥊n). w is the LAST
# axis (index d-1); the visible 3-brane is a fixed-w slice of the first d-1 axes.
# Reproducible: every seed takes an rng seed so runs are deterministic.

⟨Noise, Slab⟩⇐

# Uniform random field.  𝕩 ≡ ⟨n, d, density, rng-seed⟩
Noise ← {n‿d‿p‿s:
  r ← •MakeRand s
  sh ← d⥊n
  sh ⥊ ((×´sh) r.Range 0) < p
}

# "Feed from hidden layers": random density confined to a band of w-layers
# centred `c` cells along w (last axis), half-width `h`; zero elsewhere. So the
# action lives OFF the visible slice and drifts into it — births/deaths in the
# brane have no on-slice cause. Uses sh⥊wmask, which aligns a length-n vector to
# the last axis (verified).  𝕩 ≡ ⟨n, d, density, rng-seed, c, h⟩
Slab ← {n‿d‿p‿s‿c‿h:
  base ← Noise n‿d‿p‿s
  sh ← d⥊n
  w ← ↕n
  wmask ← (w≥c-h) ∧ w≤c+h
  base × sh⥊wmask
}
