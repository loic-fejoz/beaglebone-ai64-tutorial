#!/bin/bash
set -e

# Build the ARM64 builder container image
docker build --load -t bbai64-builder .

# Run build targets inside container
docker run --rm --platform linux/arm64 -v "$(pwd)":/workspace bbai64-builder make "$@"
