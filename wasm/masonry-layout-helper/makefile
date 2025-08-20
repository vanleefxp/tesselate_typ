build:
	@cd $(dir $(MAKEFILE_LIST)) && cargo build --release --target wasm32-unknown-unknown

copy:
	@cd $(dir $(MAKEFILE_LIST)) && pwsh -Command Copy-Item -Path "./target/wasm32-unknown-unknown/release/masonry_layout_helper.wasm" -Destination "../../src/_impl/masonry-layout-helper.wasm" -Force