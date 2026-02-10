#!/bin/bash
set -eo pipefail

# Clean and recreate the build output directory
rm -rf build
mkdir -p build

#echo "--- Formatting codebase ---"
#odinfmt -w .

echo ""
echo "--- Running tests ---"
if ! odin test ui -vet -strict-style -vet-tabs -warnings-as-errors -all-packages; then
    echo "Ui tests failed! Cannot successfully build."
    exit 1
fi

if ! odin test ui/text -vet -strict-style -vet-tabs -warnings-as-errors; then
    echo "Ui/text tests failed! Cannot successfully build."
    exit 1
fi

if ! odin test base -vet -strict-style -vet-tabs -warnings-as-errors; then
    echo "Base tests failed! Cannot successfully build."
    exit 1
fi

if ! odin test gap_buffer -vet -strict-style -vet-tabs -warnings-as-errors; then
    echo "Gap buffer tests failed! Cannot successfully build."
    exit 1
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
