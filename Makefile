
.PHONY: all test test-nocompile clean dist-clean

all: test

test:
	@make test -C test

test-nocompile:
	@make test-nocompile -C test

clean:
	make clean -C test

dist-clean:
	make dist-clean -C test
