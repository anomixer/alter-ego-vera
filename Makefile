

.PHONY: clean compile play

#
# Targets
#

all: ./target/alterego.nes

clean:
	rm -rf ./target

target:
	mkdir target

target/game.s: target src/game.c
	cc65 --include-dir ./src -Oi src/game.c --add-source -o ./target/game.s

target/crt0.o: src/crt0.s
	ca65 src/crt0.s --include-dir ./src -o target/crt0.o

target/neslib.o: src/neslib.s
	ca65 src/neslib.s --include-dir ./src -o target/neslib.o

target/game.o: target/game.s
	ca65 target/game.s -o target/game.o

target/alterego.nes: target/game.o target/crt0.o target/neslib.o
	ld65 -C src/nes.cfg -o target/alterego.nes target/crt0.o target/game.o target/neslib.o src/nes.lib

play: target/alterego.nes
	fceux ./target/alterego.nes

