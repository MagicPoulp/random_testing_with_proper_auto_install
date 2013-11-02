REBAR="./rebar"

.PHONY: test test-nocompile clean dist-clean

test:
	@$(REBAR) -j get-deps
	@$(REBAR) compile
	@$(REBAR) eunit skip_deps=true

test-nocompile:
	@$(REBAR) eunit skip_deps=true

clean:
	@$(REBAR) -j clean

dist-clean: clean
	@$(REBAR) -j delete-deps

