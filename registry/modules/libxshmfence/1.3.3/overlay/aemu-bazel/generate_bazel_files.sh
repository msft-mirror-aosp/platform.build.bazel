#!/bin/bash

set -e

# Get the absolute path of the script's directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Deduce AOSP_ROOT based on script location
# The script is in $AOSP_ROOT/third_party/libxshmfence/aemu-bazel
AOSP_ROOT=$(realpath "$SCRIPT_DIR/../../..")

# Define absolute paths for config files
CONFIG_FILE="$SCRIPT_DIR/aemu-build-config.jsonc"
SHIM_FILE="$SCRIPT_DIR/aemu-shim.jsonc"

# The directory where the python script should be run from (top of libxshmfence repo)
REPO_ROOT=$(realpath "$SCRIPT_DIR/..")

# The path to the python script
AMC_PYTHON="$AOSP_ROOT/hardware/google/aemu/tools/toolchain/src/amc.py"

# The output build path. This directory will contain the zip file containing
# the BUILD file and config.h
AMC_BUILD_PATH="$SCRIPT_DIR/amc-build"

# Change to the repository root to run the script
cd "$REPO_ROOT"

# Generate bazel build files with amc.py:
python3 "$AMC_PYTHON" -v bazel \
    --config "$CONFIG_FILE" \
    --aosp "$AOSP_ROOT" \
    --shim "$SHIM_FILE" \
    "$AMC_BUILD_PATH"

echo "Done! Unzip the zip file in $AMC_BUILD_PATH to the repo root " \
     "($REPO_ROOT) to get the bazel files"
