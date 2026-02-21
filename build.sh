#!/bin/bash
set -eo pipefail

usage() {
    echo "Usage: $0 [all|test]"
    echo ""
    echo "  all   Run tests, build main app, and build examples (default)"
    echo "  test  Run tests only"
}

mode="${1:-all}"
if [[ "$mode" != "all" && "$mode" != "test" ]]; then
    usage
    exit 1
fi

# Clean and recreate the build output directory
rm -rf build
mkdir -p build

#echo "--- Formatting codebase ---"
#odinfmt -w .

echo ""
echo "--- Running tests ---"
./test.sh

if [[ "$mode" == "test" ]]; then
    echo ""
    echo "Tests completed successfully."
    exit 0
fi

echo ""
echo "--- Building main application ---"
if ! odin build . -vet -strict-style -vet-tabs -warnings-as-errors -debug -out:./build/sgui.bin; then
    echo "Build failed!"
    exit 1
fi

echo ""
echo "--- Building all examples ---"
for example_path in examples/*/; do
    # Remove the trailing slash and the 'examples/' prefix to get the name
    example_name=$(basename "$example_path")
    
    echo "Building example: $example_name"
    if ! odin build "$example_path" -vet -strict-style -vet-tabs -warnings-as-errors -debug -out:./build/"$example_name".bin; then
        echo "Build for example '$example_name' failed!"
        exit 1
    fi
done

echo ""
echo "Build and tests completed successfully."
