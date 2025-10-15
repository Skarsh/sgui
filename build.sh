#!/bin/bash
set -eo pipefail

echo "Running tests"
if ! odin test ui; then
    echo "Ui tests failed! Cannot successfully build."
    exit 1
fi

if ! odin test base; then
    echo "Base tests failed! Cannot successfully build."
    exit 1
fi

echo "Building main"
if ! odin build . -strict-style -vet -debug -out:./build/sgui.bin; then
    echo "Build failed!"
    exit 1
fi

echo "Building counter example"
if ! odin build examples/counter -strict-style -vet -debug -out:./build/counter.bin; then
    echo "Build failed!"
    exit 1
fi

echo "Build and tests completed successfully."
