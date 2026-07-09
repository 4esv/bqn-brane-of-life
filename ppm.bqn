# ppm.bqn — binary PPM (P6) writer.
#
# No external BQN graphics dep: a P6 file is a tiny ASCII header followed by raw
# RGB bytes, so we emit it directly. netpbm's pnmtopng isn't installed on this
# box, but ffmpeg/ImageMagick read PPM natively (verified), so the frame →
# PNG/video step lives in the makefile, not here.

⟨Write⟩⇐

# Write an H×W×3 array of 0..255 integers to path 𝕨 as a P6 PPM.
# ⥊img is row-major r,g,b,r,g,b… — exactly P6 pixel order.
Write ← {path 𝕊 img:
  h‿w‿c ← ≢img
  hdr ← "P6"∾(@+10)∾(•Repr w)∾" "∾(•Repr h)∾(@+10)∾"255"∾(@+10)
  path •FBytes (-⟜@ hdr) ∾ ⥊ ⌊ img
}
