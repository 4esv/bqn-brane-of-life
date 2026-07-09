# bqn-brane-of-life — build the piece.
#   make test          run the engine correctness gate
#   make search        hunt for living 4D rules → rules.md
#   make hero          render the flagship loop → assets/hero.gif + out/brane.mp4
#   make clean         remove frames/ and out/
#
# Only non-BQN dep is ffmpeg (PPM → video/gif). netpbm's pnmtopng isn't needed.

BQN    ?= bqn
K      ?= 3
D      ?= 4
N      ?= 32
STEPS  ?= 96
RULE   ?= S4/B4
SEED   ?= 42
PX     ?= 800
FPS    ?= 6
GIFPX  ?= 440
GIFCOL ?= 64
SN     ?= 12

.PHONY: test search frames mp4 gif hero clean

test:
	$(BQN) test/test_life.bqn

search:
	$(BQN) search.bqn $(D) $(SN)

frames:
	@mkdir -p frames
	@rm -f frames/*.ppm
	$(BQN) brane.bqn k=$(K) d=$(D) n=$(N) steps=$(STEPS) rule=$(RULE) seed=$(SEED) px=$(PX) out=frames

mp4: frames
	@mkdir -p out
	ffmpeg -y -framerate $(FPS) -i frames/%04d.ppm \
	  -c:v libx264 -pix_fmt yuv420p -movflags +faststart out/brane.mp4

# web-friendly hero gif: generated palette, capped colours + bayer dither (the
# busy voxel field is gif-hostile, so we downscale and quantise to stay small)
gif: frames
	@mkdir -p out assets
	ffmpeg -y -i frames/%04d.ppm \
	  -vf "scale=$(GIFPX):-1:flags=lanczos,palettegen=max_colors=$(GIFCOL)" -update 1 out/palette.png
	ffmpeg -y -framerate $(FPS) -i frames/%04d.ppm -i out/palette.png \
	  -lavfi "scale=$(GIFPX):-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3" \
	  -loop 0 assets/hero.gif
	@echo "gif → assets/hero.gif ($$(du -h assets/hero.gif | cut -f1))"

hero: mp4 gif
	@mkdir -p assets
	ffmpeg -y -i "$$(ls frames/*.ppm | tail -1)" -update 1 assets/hero.png
	@echo "hero → assets/hero.gif, assets/hero.png, out/brane.mp4"

clean:
	rm -rf frames out
