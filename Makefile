RGBASM ?= rgbasm
RGBLINK ?= rgblink
RGBFIX ?= rgbfix

.PHONY: all
all: build/MersenneBoy.gb

build:
	mkdir build

build/main.o: src/main.asm src/display.asm src/font.bin | build
	$(RGBASM) -Wall -Wextra -o $@ $<

build/MersenneBoy.gb: build/main.o
	$(RGBLINK) -p 255 -n build/MersenneBoy.sym -m build/MersenneBoy.map -o $@ $<
	$(RGBFIX) -v -c -p 255 -t MERSENNEBOY -m 0 -r 0 $@

