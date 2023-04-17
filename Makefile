.PHONY: build
build:
	cargo build --release
	mkdir -p ./lua/deps/
	mkdir -p ./lib/
	rm -f ./lua/libgithub_search.so
	cp ./target/release/libgithub_search.dylib ./lua/libgithub_search.so
	# if your Rust project has dependencies,
	# you'll need to do this as well
	cp ./target/release/deps/*.rlib ./lua/deps/
