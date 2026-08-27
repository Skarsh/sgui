#!/bin/bash
set -eo pipefail
usage() {
    echo "Usage: $0 [all|test|build]"
    echo ""
    echo "  all    Run tests, build main app, and build examples (default)"
    echo "  test   Run tests only"
    echo "  build  Build main app and examples only (no tests)"
}
mode="${1:-all}"
if [[ "$mode" != "all" && "$mode" != "test" && "$mode" != "build" ]]; then
    usage
    exit 1
fi

# Clean and recreate the build output directory
rm -rf build
mkdir -p build

if [[ "$mode" != "build" ]]; then
    echo ""
    echo "--- Running tests ---"
    ./test.sh
    if [[ "$mode" == "test" ]]; then
        echo ""
        echo "Tests completed successfully."
        exit 0
    fi
fi

echo ""
echo "--- Building all examples ---"
if ! odin run parbuild -- ./examples ./build; then
    echo "Building examples with parbuild failed!"
    exit 1
fi
echo ""
echo "Examples built successfully."
