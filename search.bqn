# search.bqn — hunt for survive/birth rules that LIVE in higher-D Life.
#
# Hard problem #1+#2 (they're one search): Conway B3/S23 dies in 4D (80-cell
# neighbourhood). We need a rule that (a) survives, (b) stays SPARSE so the cube
# is translucent and interior churn shows through, (c) actually churns (not a
# frozen still-life). Sweeps random interval rules S[s0..s1]/B[b0..b1], scores
# each on one shared reproducible seed, ranks them, writes rules.md.
#
# Run:  bqn search.bqn [d] [n]     e.g.  bqn search.bqn 4 12

eng  ← •Import "life.bqn"
seed ← •Import "seed.bqn"

# ── params (positional: d, n) ────────────────────────────────────────────────
d    ← {0<≠•args ? •BQN ⊑•args ; 4}
n    ← {1<≠•args ? •BQN 1⊑•args ; 12}
kg    ← 45         # generations per trial
nc    ← 800        # candidate rules to sample
dens ← 0.12       # seed density
rs   ← 1234       # rng seed (reproducible)
topN ← 20
target ← 0.08     # ideal live density (sparse = translucent)

cells ← ×´ d⥊n
cap   ← ⌊ 0.6×cells
seed0 ← seed.Noise n‿d‿dens‿rs

# round x to 3 decimals, shown as an integer ×1000 (keeps formatting trivial)
M ← {⌊0.5+1000×𝕩}

# ── evaluate a rule: kg gens from seed0, early-exit on death/explosion ─────────
Metrics ← {rule←𝕩
  traj  ← ⟨rule, kg⟩ eng.Trajectory seed0     # list of kg+1 grids
  pops  ← {+´⥊𝕩}¨ traj
  chg   ← (1↓traj) {𝕨≢𝕩}¨ ¯1↓traj             # did each consecutive state change?
  churn ← (+´chg) ÷ 1⌈≠chg
  died     ← ∨´ pops=0
  maxD     ← (⌈´pops) ÷ cells
  exploded ← maxD > 0.55
  survived ← (¬died) ∧ ¬exploded
  meanD    ← (+´pops) ÷ cells×≠pops
  inBand   ← (meanD≥0.02) ∧ meanD≤0.25
  score    ← (survived×inBand) × churn × 1÷1+8×|meanD-target
  ⟨score, rule, meanD, maxD, churn, survived⟩
}

# ── candidates: Conway first (should die in 4D), then random interval rules ───
rr ← •MakeRand rs+1
Cand ← {𝕩  # 𝕩 ignored (forces function role); each call advances the shared rng rr
  s0←3+rr.Range 10 ⋄ sw←rr.Range 5
  b0←3+rr.Range 10 ⋄ bw←rr.Range 3
  ⟨s0+↕1+sw, b0+↕1+bw⟩
}
# ── rule → "S5-7/B6" ─────────────────────────────────────────────────────────
Rng ← {(⊑𝕩)=¯1⊑𝕩 ? •Repr ⊑𝕩 ; (•Repr ⊑𝕩)∾"-"∾•Repr ¯1⊑𝕩}
RuleStr ← {s‿b: "S"∾(Rng s)∾"/B"∾Rng b}

cands ← (<⟨2‿3, ⟨3⟩⟩) ∾ Cand¨ ↕nc
cands ↩ (∊ RuleStr¨ cands) / cands           # drop resampled duplicates

res    ← Metrics¨ cands
ranked ← (⍒ ⊑¨res) ⊏ res
survivors ← +´ {5⊑𝕩}¨ res

# ── stdout summary ────────────────────────────────────────────────────────────
•Out "searched "∾(•Repr nc)∾" rules at d="∾(•Repr d)∾" n="∾(•Repr n)∾", kg="∾•Repr kg
•Out (•Repr survivors)∾" survived full run; metrics ×1000. top "∾(•Repr topN)∾":"
•Out "score  rule            meanD  maxD  churn  (×1000)"
Pad ← {𝕨 ↑ 𝕩 ∾ 𝕨⥊' '}   # left-justify 𝕩 into width 𝕨
Row ← {sc‿rule‿mD‿xD‿ch‿ok: (6 Pad •Repr M sc)∾(16 Pad RuleStr rule)∾(7 Pad •Repr M mD)∾(6 Pad •Repr M xD)∾(•Repr M ch)}
•Out∘Row¨ topN↑ranked

# ── rules.md ──────────────────────────────────────────────────────────────────
MdRow ← {sc‿rule‿mD‿xD‿ch‿ok: "| `"∾(RuleStr rule)∾"` | "∾(•Repr M sc)∾" | "∾(•Repr M mD)∾" | "∾(•Repr M xD)∾" | "∾(•Repr M ch)∾" |"}
head ← ⟨
  "# Rule leaderboard — d="∾(•Repr d)∾", n="∾(•Repr n)∾", seed density "∾(•Repr dens)∾", "∾(•Repr kg)∾" gens"
  ""
  "One shared reproducible seed. meanD/maxD/churn shown ×1000."
  "Score = full-survival × in-band-sparse-density (~"∾(•Repr target)∾") × churn."
  ""
  "| rule | score | meanD | maxD | churn |"
  "|---|---|---|---|---|"
⟩
lines ← head ∾ MdRow¨ topN↑ranked
md ← ∾ {𝕩∾@+10}¨ lines
(•wdpath∾"/rules.md") •FChars md
•Out "wrote rules.md"
