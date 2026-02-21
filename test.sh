#!/bin/bash
set -eo pipefail

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
