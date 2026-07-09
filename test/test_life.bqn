# test/test_life.bqn — correctness gate for the engine.
#
# Proves d=2 Conway behaviour (the rule everyone can check by hand) before any
# 4D work trusts the engine. Also smoke-tests that the *same* code runs at d=3
# and d=4. To run: bqn test/test_life.bqn  (exits 1 on any failure — `make test`).

eng ← •Import "../life.bqn"   # engine namespace; use eng.Life / eng.Run

conway ← ⟨2‿3, ⟨3⟩⟩       # B3/S23

# place a small pattern p into the top-left of an n×n board of zeros
Board ← {p 𝕊 n: p ⌾ ((≢p)⊸↑) (n‿n⥊0)}

# ── patterns ────────────────────────────────────────────────────────────────
blinker ← >⟨0‿0‿0, 1‿1‿1, 0‿0‿0⟩
glider  ← >⟨0‿1‿0, 0‿0‿1, 1‿1‿1⟩
block   ← >⟨1‿1, 1‿1⟩

bl ← blinker Board 5
gl ← glider  Board 8
bk ← block   Board 6

gl4 ← ⟨conway,4⟩ eng.Run gl    # glider after one full period
# after 4 gens a glider = the original shifted one step along a diagonal
# (which diagonal depends on orientation) under the toroidal wrap
glShifts ← {𝕩⌽gl}¨ ⟨1‿1, 1‿¯1, ¯1‿1, ¯1‿¯1⟩

# live d=3 / d=4 blobs to exercise rank-polymorphism (shape must be conserved)
g3 ← 4‿4‿4   ⥊ 1‿0‿0‿1‿0‿1‿1‿0
g4 ← 4‿4‿4‿4 ⥊ 1‿0‿0‿1‿0‿1‿1‿0

# ── checks: ⟨name, boolean⟩ ──────────────────────────────────────────────────
tests ← ⟨
  ⟨"d2 blinker changes after 1 gen",    (conway eng.Life bl) ≢ bl⟩
  ⟨"d2 blinker period 2",               (⟨conway,2⟩ eng.Run bl) ≡ bl⟩
  ⟨"d2 block is a still life",           (⟨conway,10⟩ eng.Run bk) ≡ bk⟩
  ⟨"d2 glider conserves population",     (+´⥊gl4) = +´⥊gl⟩
  ⟨"d2 glider translates diagonally",    (∨´gl4⊸≡¨glShifts) ∧ gl4≢gl⟩
  ⟨"d3 step runs, shape conserved",      (≢conway eng.Life g3) ≡ ≢g3⟩
  ⟨"d4 step runs, shape conserved",      (≢conway eng.Life g4) ≡ ≢g4⟩
  ⟨"d4 rank stays 4 (dimension-agnostic)", (=conway eng.Life g4) = 4⟩
⟩

# ── report ───────────────────────────────────────────────────────────────────
{ n‿ok←𝕩 ⋄ •Out (⊑"FAIL"‿"ok  "⊏˜ok)∾" "∾n }¨ tests
nfail ← +´ ¬ {1⊑𝕩}¨ tests
•Out "──────────────────"
•Out (•Repr nfail)∾" failing / "∾(•Repr ≠tests)∾" total"
•Exit 0<nfail
