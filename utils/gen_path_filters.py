#!/usr/bin/env python3
"""
Bazel Path Translation Utility.

This script generates sed replacement expressions to translate Bazel's internal
paths (e.g., external/module_name+/, @@module_name//) back to their actual
locations within the source tree. This is primarily used to make file paths
in Bazel build/test output clickable in IDEs like Visual Studio Code.
"""

import json
import pathlib
import sys


def generate_filters():
    """
    Scans the Bazel registry for local modules and generates sed filters.

    The function looks into build/bazel/registry/modules to find all modules
    defined with a "local_path" type. For each found module, it creates
    regular expression replacements for:
    1. Bzlmod canonical paths (external/name+/)
    2. Canonical labels (@@name//)
    3. Apparent labels (@name//)

    Returns:
        str: A semicolon-separated string of sed replacement expressions.
             Returns "s|X|X|g" (a no-op) if no registry or modules are found.
    """
    filters = set()
    # The registry is located at build/bazel/registry
    registry_path = pathlib.Path("build/bazel/registry/modules")

    if not registry_path.exists():
        # Fallback to a no-op filter if registry is missing
        return "s|X|X|g"

    # Scan for all source.json files in the registry
    for source_json in registry_path.glob("*/*/source.json"):
        try:
            with source_json.open() as f:
                data = json.load(f)

            # We only care about local_path modules as these exist in our source tree
            if data.get("type") == "local_path" and data.get("path"):
                # module_name is the name of the directory two levels up
                module_name = source_json.parts[-3]
                local_path = data["path"]

                # Create filters for various ways Bazel refers to these modules:
                # 1. Bzlmod external path: external/mod_name+/
                filters.add(f"s|external/{module_name}[+]/|{local_path}/|g")
                # 2. Canonical label: @@mod_name//
                filters.add(f"s|@@{module_name}//|{local_path}/|g")
                # 3. Apparent label: @mod_name//
                filters.add(f"s|@{module_name}//|{local_path}/|g")
        except (json.JSONDecodeError, KeyError, IOError):
            # Skip malformed or inaccessible files
            continue

    # Join all filters with newlines for sed
    return "\n".join(sorted(filters)) or "s|X|X|g"


if __name__ == "__main__":
    print(generate_filters())
