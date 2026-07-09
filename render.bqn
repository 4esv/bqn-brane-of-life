# render.bqn — render a k-dimensional brane to an RGB raster, for k ∈ 1..4.
#
# The engine and AxisDom are dimension-agnostic, so the only per-k work is how a
# k-D slice is drawn:
#   k=1  a vertical line of cells
#   k=2  a flat square grid            (classic Life view)
#   k=3  isometric voxel splat         (the flagship)
#   k=4  a grid of iso cubes           (small multiples over the 4th visible axis)
# Every cell/voxel is coloured by its dominant neighbour axis (cval) via palette;
# for k=3/4 depth also modulates brightness so the volume reads.
#
# Frame dispatches on rank(brane). cfg ≡ ⟨px, margin, bg, box-rgb, palette⟩,
# 𝕩 ≡ ⟨brane, cval⟩ (both rank k). Returns px×px×3 integers.

⟨Frame⟩⇐

# ── shared raster helpers ─────────────────────────────────────────────────────

# nearest-neighbour upscale of an h×w×3 image by integer factor s
Upscale ← {s 𝕊 im: 1‿0‿2⍉ s⊸/ 1‿0‿2⍉ s⊸/ im}

# place image im centred on a px×px×3 background bg (gather + masked write)
Blit ← {px‿bg 𝕊 im:
  ih‿iw‿ic ← ≢im
  oy ← ⌊(px-ih)÷2 ⋄ ox ← ⌊(px-iw)÷2
  ry ← (↕px)-oy ⋄ rx ← (↕px)-ox
  vy ← (ry≥0)∧ry<ih ⋄ vx ← (rx≥0)∧rx<iw
  g1 ← ((ih-1)⌊0⌈ry) ⊏ im               # px×iw×3
  g2 ← {((iw-1)⌊0⌈rx)⊏𝕩}˘ g1            # px×px×3
  m  ← ⥊ vy ∧⌜ vx
  px‿px‿3 ⥊ (m/(px×px)‿3⥊g2) ⌾ (m⊸/) (px×px)‿3⥊bg
}

# ── k ≤ 2: flat grid of cells (1D → n×1 column, 2D → n×n square) ───────────────
Flat ← {px‿margin‿bg‿boxrgb‿pal 𝕊 brane‿cval:
  r‿c ← 2↑ (≢brane)∾1
  b2 ← r‿c ⥊ brane ⋄ v2 ← r‿c ⥊ cval
  pal2 ← pal ∾ ≍bg                       # bg as an extra palette row for dead cells
  idx ← ((⥊b2)×⥊v2) + (¬⥊b2)×≠pal
  colimg ← r‿c‿3 ⥊ idx ⊏ pal2
  s ← 1⌈ ⌊ (px-2×margin) ÷ c⌈r
  ⟨px, bg⟩ Blit s Upscale colimg
}

# ── k = 3: isometric voxel splat (painter's algorithm as a vectorised z-buffer) ─
Cube ← {px‿margin‿bg‿boxrgb‿pal 𝕊 brane‿cval:
  n ← ⊑ ≢brane
  h ← px ⋄ w ← px
  c30 ← 0.8660254038 ⋄ s30 ← 0.5
  pitch ← ((px÷2)-margin) ÷ 1⌈n-1
  hc ← (n-1)÷2

  Project ← {m←𝕩
    t ← ⍉ m
    xc←0⊏t ⋄ yc←1⊏t ⋄ zc←2⊏t
    x←xc-hc ⋄ y←yc-hc ⋄ z←zc-hc
    col ← ⌊ 0.5 + (w÷2) + pitch × (x-z)×c30
    row ← ⌊ 0.5 + (h÷2) - pitch × ((x+z)×s30)-y
    ⟨row, col, xc+yc+zc⟩
  }

  hr ← pitch×0.46 ⋄ rad ← ⌈hr ⋄ side ← 1+2×rad
  g ← ⍉ > ⥊ ↕ side‿side
  u ← (1⊏g)-rad ⋄ v ← (0⊏g)-rad
  inhex ← ((|u) ≤ c30×hr) ∧ ((|v)+(|u)÷1.7320508) ≤ hr
  sdr ← inhex/v ⋄ sdc ← inhex/u ⋄ ss ← ≠sdr

  co ← (⥊brane)/⥊↕≢brane
  Vox ← {𝕤
    vr‿vc‿vd ← Project > co
    dmn ← ⌊´vd ⋄ shade ← (vd-dmn) ÷ 0.0001⌈(⌈´vd)-dmn
    cats ← (⥊brane) / ⥊cval
    bri  ← 0.42 + 0.58 × shade
    rgbVox ← ⌊ ⍉ {𝕩×bri}˘ ⍉ cats⊏pal
    ⟨ ⥊ vr +⌜ sdr, ⥊ vc +⌜ sdc, ⥊ vd +⌜ 0×sdr, ss / rgbVox ⟩
  }
  vR‿vC‿vD‿vRGB ← {0<≠co ? Vox@ ; ⟨⟨⟩,⟨⟩,⟨⟩, 0‿3⥊0⟩}

  corners ← (n-1) × > ⥊ ↕2‿2‿2
  edges ← ⟨0‿1,2‿3,4‿5,6‿7, 0‿2,1‿3,4‿6,5‿7, 0‿4,1‿5,2‿6,3‿7⟩
  ts ← (↕1+t) ÷ t←⌈2×pitch×n
  BoxEdge ← {s←(⊑𝕩)⊏corners ⋄ e←(1⊑𝕩)⊏corners ⋄ ((≠ts)‿3⥊s) + ts ×⌜ e-s}
  bR‿bC‿bD ← Project ∾ BoxEdge¨ edges
  bRGB ← (≠bR)‿3 ⥊ boxrgb

  rr ← vR∾bR ⋄ cc ← vC∾bC ⋄ dd ← vD∾bD ⋄ rgb ← vRGB∾bRGB
  inb ← (rr≥0)∧(rr<h)∧(cc≥0)∧cc<w
  rr↩inb/rr ⋄ cc↩inb/cc ⋄ dd↩inb/dd ⋄ rgb↩inb/rgb
  pi ← (rr×w)+cc
  ord ← ⍋dd
  pi↩ord⊏pi ⋄ rgb↩ord⊏rgb
  keep ← ⌽ ∊ ⌽ pi
  raster ← (h×w)‿3 ⥊ bg
  raster ↩ (keep/rgb) ⌾ ((keep/pi)⊸⊏) raster
  (h‿w‿3) ⥊ raster
}

# ── k = 4: small multiples — one iso cube per index of the 4th visible axis ────
Tess ← {px‿margin‿bg‿boxrgb‿pal 𝕊 brane‿cval:
  n    ← ⊑ ≢brane
  cols ← ⌈ n ⋆ 0.5
  rows ← ⌈ n ÷ cols
  tpx  ← ⌊ px ÷ cols
  tcfg ← ⟨tpx, ⌊tpx÷14, bg, boxrgb, pal⟩
  Tile ← {j←𝕩 ⋄ tcfg Cube ⟨(j⊸⊑)⎉1 brane, (j⊸⊑)⎉1 cval⟩}
  padded ← (Tile¨ ↕n) ∾ (0⌈(rows×cols)-n) ⥊ ⟨tpx‿tpx‿3⥊bg⟩
  Hcat ← {1‿0‿2⍉ ∾ 1‿0‿2⊸⍉¨ 𝕩}
  ⟨px, bg⟩ Blit ∾ {Hcat cols↑ (cols×𝕩)↓ padded}¨ ↕rows
}

# ── dispatch on visible dimension (rank of the brane) ─────────────────────────
Frame ← {
  (2 ≥ =⊑𝕩) ? 𝕨 Flat 𝕩 ;
  (4 ≤ =⊑𝕩) ? 𝕨 Tess 𝕩 ;
  𝕨 Cube 𝕩
}
