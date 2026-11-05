default: build

setup:
    @bash scripts/setup.sh

build: setup
    @.tools/roc/roc scripts/build.roc

run: build
    @cargo run --quiet --bin birdcage

test: build
    @.tools/roc/roc scripts/test.roc

fmt: setup
    @.tools/roc/roc scripts/fmt.roc

lint: build
    @.tools/roc/roc scripts/lint.roc

clean:
    @cargo clean
    @rm -rf build
