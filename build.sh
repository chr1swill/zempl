#!/bin/sh

set -xe

BIN="bin"
#ZFLAGS="-lc -O Debug -femit-bin=${BIN}/main -femit-asm=${BIN}/main.s -ofmt=elf"
ZFLAGS="-lc -O Debug -femit-bin=${BIN}/main"

#if [ -d "$BIN" ]; then
#  rm -rf "$BIN"
#fi

mkdir -p "$BIN"

zig build-exe ${ZFLAGS} src/main.zig
