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
	cp ./target/release/libgithub_search.$(LIB_EXT) ./lua/libgithub_search.$(LIB_EXT)
	
	# If your Rust project has dependencies,
	# you'll need to do this as well
	cp ./target/release/deps/*.rlib ./lua/deps/
