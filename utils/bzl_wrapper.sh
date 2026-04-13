#!/usr/bin/env bash
# Wrapper for Bazel that translates internal paths to source tree paths.
# This makes paths clickable in VS Code and Jetski.

# Ensure we are in the Bazel root
cd "${BAZEL_ROOT}" || exit 1

# If no filters are provided, use a no-op
filters="${BZL_SED_FILTERS:-s|X|X|g}"

# Detect OS for sed unbuffered flag
case "$(uname)" in
    Linux*)  SED_FLAG="-u" ;;
    Darwin*) SED_FLAG="-l" ;;
    *)       SED_FLAG="-u" ;;
esac

# Run Bazel with forced color
# 1. Redirect stdout through sed
# 2. Redirect stderr through sed and back to stderr
bazel "$1" --color=yes "${@:2}" \
    1> >(sed "${SED_FLAG}" "${filters}") \
    2> >(sed "${SED_FLAG}" "${filters}" >&2)
