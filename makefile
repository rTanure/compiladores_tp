LEXER_STANDALONE  ?= OFF
INPUT  ?= inputs/ok_2.txt

TARGET = parser

.PHONY: run build clean

run: build
	./build/${TARGET} < $(INPUT)

build:
	cmake -S . -B build -DLEXER_STANDALONE=$(LEXER_STANDALONE)
	cmake --build build

clean:
	rm -rf build