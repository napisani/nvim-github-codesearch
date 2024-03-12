.PHONY: build
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	LIB_EXT := dylib
else
	LIB_EXT := so
endif
build:
	cargo build --release
	mkdir -p ./lua/deps/
	mkdir -p ./lib/
	
	# Remove old shared library
	rm -f ./lua/libgithub_search.$(LIB_EXT)
	
	# Copy new shared library to target directory
	# NOTE: Use .so even on Mac due to weird issue loading .dylib
	# https://github.com/Joakker/lua-json5/issues/4
	# https://github.com/neovim/neovim/issues/21749#issuecomment-1418427487
	cp ./target/release/libgithub_search.$(LIB_EXT) ./lua/libgithub_search.so
	
	# If your Rust project has dependencies,
	# you'll need to do this as well
	cp ./target/release/deps/*.rlib ./lua/deps/
