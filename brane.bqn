# brane.bqn — the piece (with the tool underneath).
#
# Evolve a d-D Life automaton, slice the visible 3-brane at w=0 each generation,
# iso-render it to a PPM frame. The makefile assembles the frames into the loop.
# For the flagship d=4: you watch a 3D volume, but ~67.5% of every cell's fate
# comes from the hidden w-axis, so births/deaths in the brane look uncaused.
#
# Run:  bqn brane.bqn [k=v …]
#   d=4 n=32 steps=240 rule=S3-6/B3 seed=42 dens=0.16 wc=1 wh=1 px=800 out=frames
# The engine is general (any d, any S/B rule); only the render assumes the sliced
# brane is 3D (true for d≥3, sliced d-3 times).

eng  ← •Import "life.bqn"
seed ← •Import "seed.bqn"
rnd  ← •Import "render.bqn"
ppm  ← •Import "ppm.bqn"

# ── tiny arg + rule parsing ───────────────────────────────────────────────────
Cut ← {d 𝕊 str: s←d≠str ⋄ (s / ¯1 + +`»⊸<s) ⊔ s/str}      # split str on char d
# "3-6" | "3,5" | "5" | "3-6,9" → flat list of neighbour counts
ParseSet ← {toks←','Cut 𝕩 ⋄ ∾ {nums←•ParseFloat¨'-'Cut 𝕩 ⋄ a←⊑nums ⋄ a+↕1+(¯1⊑nums)-a}¨ toks}
# "S3-6/B3" → ⟨survive-list, birth-list⟩  (S part then B part)
ParseRule ← {parts←'/'Cut 𝕩 ⋄ ⟨ParseSet 1↓⊑parts, ParseSet 1↓1⊑parts⟩}

kv   ← {'='Cut 𝕩}¨ •args
kv   ↩ (2=≠¨kv)/kv                               # keep only well-formed k=v
keys ← ⊑¨kv ⋄ vals ← {1⊑𝕩}¨kv
Sget ← {def 𝕊 key: ⊑ ((key⊸≡¨keys)∾1) / vals∾⟨def⟩}   # first match, else default
Nget ← {def 𝕊 key: •ParseFloat def Sget key}     # numeric option, with default

# ── config ────────────────────────────────────────────────────────────────────
d      ← "4"   Nget "d"                           # automaton dimension (total)
k      ← "3"   Nget "k"                           # visible dimension of the brane
n      ← "32"  Nget "n"
steps  ← "240" Nget "steps"
px     ← "800" Nget "px"
sk     ← "42"  Nget "seed"                        # rng seed
dens   ← "0.16" Nget "dens"
wc     ← "1"   Nget "wc"                           # slab centre along the hidden axes
wh     ← "1"   Nget "wh"                           # slab half-width
ruleS  ← "S4/B4" Sget "rule"    # flagship: smooth (no B3 strobe), sparse, high churn
rule   ← ParseRule ruleS
outdir ← "frames" Sget "out"
w0     ← 0                                         # fixed slice index on hidden axes
"need 1≤k≤4 and k≤d" ! (1≤k)∧(k≤4)∧(k≤d)
# per-axis palette (cycled to d): x=blue y=green z=amber w=magenta (the first
# hidden axis, made to pop) v=purple. A cell's hue is the axis most of its
# neighbours lie along, so magenta = driven mainly from off-slice.
base   ← >⟨ 66‿160‿205, 90‿195‿115, 232‿180‿74, 236‿72‿150, 150‿95‿222 ⟩
pal    ← ((≠base)|↕⌈d) ⊏ base
cfg    ← ⟨px, ⌊px÷20, 18‿18‿26, 70‿70‿90, pal⟩     # px, margin, bg, wireframe, palette

invis ← ((3⋆d)-3⋆k) ÷ (3⋆d)-1                      # invisible fraction for the k-slice

•Out "brane: "∾(•Repr k)∾"D slice of "∾(•Repr d)∾"D · n="∾(•Repr n)∾" rule="∾ruleS∾" steps="∾•Repr steps
•Out "invisible fraction (hidden-axis share of each cell's fate): "∾(•Repr ⌊0.5+1000×invis)∾"‰"

# ── evolve, slice, render ───────────────────────────────────────────────────────
g0     ← {d>k ? seed.Slab n‿d‿dens‿sk‿wc‿wh ; seed.Noise n‿d‿dens‿sk}
frames ← ⟨rule, steps⟩ eng.Trajectory g0          # list of steps+1 grids
Brane  ← ((w0⊸⊑)⎉1)⍟(d-k)                          # slice hidden axes down to k-D
Pad4   ← {s←•Repr 𝕩 ⋄ ((0⌈4-≠s)⥊'0')∾s}
Path   ← {(•wdpath)∾"/"∾outdir∾"/"∾(Pad4 𝕩)∾".ppm"}

Draw ← {i←𝕩
  gf ← i⊑frames                                    # full d-D state
  img ← cfg rnd.Frame ⟨Brane gf, Brane eng.AxisDom gf⟩
  (Path i) ppm.Write img
  (0=20|i) ◶ ⟨⊢, {𝕤⋄•Out "  frame "∾(•Repr i)∾"/"∾•Repr steps}⟩ @
}
Draw¨ ↕≠frames
•Out "done: "∾(•Repr ≠frames)∾" frames → "∾outdir∾"/"
