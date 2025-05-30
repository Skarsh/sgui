#!/bin/bash
set -eo pipefail

echo "Running tests"
if ! odin test ui; then
    echo "Tests failed! Cannot successfully build."
    exit 1
fi

echo "Building SDL2 example"
if ! odin build . -strict-style -vet -debug; then
    echo "Build failed!"
    exit 1
fi

echo "Build and tests completed successfully."
