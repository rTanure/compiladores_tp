MODE   ?= ON
INPUT  ?= inputs/input.txt

.PHONY: run build clean

run: build
	./build/lexer < $(INPUT)

build:
	cmake -S . -B build -DLEXER_STANDALONE=$(MODE)
	cmake --build build

clean:
	rm -rf build