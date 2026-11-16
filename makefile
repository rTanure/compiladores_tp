INPUT  ?= inputs/input.txt

TARGET = compilador

.PHONY: run build test clean

run: build
	./build/${TARGET} < $(INPUT)

build:
	cmake -S . -B build
	cmake --build build

# Roda todos os arquivos de teste. Os "ok" devem passar; os "erros_*" devem falhar.
test: build
	@for f in inputs/input.txt inputs/ok.txt; do \
		./build/${TARGET} < $$f > /dev/null 2>&1 && echo "PASSOU  $$f" || echo "FALHOU  $$f (esperado sucesso)"; \
	done
	@for f in inputs/erros_*.txt inputs/sem_principal.txt; do \
		./build/${TARGET} < $$f > /dev/null 2>&1 && echo "FALHOU  $$f (esperado erro)" || echo "PASSOU  $$f"; \
	done

clean:
	rm -rf build
