INPUT  ?= inputs/ok_2.txt

TARGET = parser

.PHONY: run build clean

run: build
	./build/${TARGET} < $(INPUT)

build:
	cmake -S . -B build
	cmake --build build

clean:
	rm -rf build