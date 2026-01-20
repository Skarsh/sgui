#!/bin/bash
set -eo pipefail

# Ensure the build output directory exists
mkdir -p build

echo "--- Formatting codebase ---"
odinfmt -w .

echo ""
echo "--- Running tests ---"
if ! odin test ui; then
    echo "Ui tests failed! Cannot successfully build."
    exit 1
fi

if ! odin test base; then
    echo "Base tests failed! Cannot successfully build."
    exit 1
fi

echo ""
echo "--- Building main application ---"
if ! odin build . -strict-style -vet -debug -out:./build/sgui.bin; then
    echo "Build failed!"
    exit 1
fi

echo ""
echo "--- Building all examples ---"
for example_path in examples/*/; do
    # Remove the trailing slash and the 'examples/' prefix to get the name
    example_name=$(basename "$example_path")
    
    echo "Building example: $example_name"
    if ! odin build "$example_path" -strict-style -vet -debug -out:./build/"$example_name".bin; then
        echo "Build for example '$example_name' failed!"
        exit 1
    fi
done

echo ""
echo "Build and tests completed successfully."
