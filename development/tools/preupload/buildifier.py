#!/usr/bin/env python3
# Copyright 2023 - The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the',  help='License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an',  help='AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import os
import subprocess
import sys
import shutil
from pathlib import Path


def main():
    # TODO(jansene): Make this check global and rely on prebuilt bazel
    if not shutil.which("bazel"):
        print("bazel not available, ignoring test")
        return 0

    # Get the list of files from the command line arguments
    abs_files = [Path(x).absolute() for x in sys.argv[1:]]
    files = [str(x) for x in abs_files if is_bazel_file(x)]
    if not files:
        print("No Bazel files found, ignoring test")
        return 0

    try:
        subprocess.check_call(
            [
                "bazel",
                "run",
                "--",
                "@buildifier_prebuilt//:buildifier",
                "-mode=check",
                "-lint=warn",
            ]
            + files
        )
    except subprocess.CalledProcessError as cpe:
        subprocess.check_call(
            [
                "bazel",
                "run",
                "--",
                "@buildifier_prebuilt//:buildifier",
                "-mode=fix",
                "-lint=fix",
            ]
            + files
        )
        sys.exit(1)


def is_bazel_file(path: Path) -> bool:
    """Checks if the given file path corresponds to a Bazel file.

    These are basically the set of files that gerrit will consider when
    running lint checks.

    Args:
        file_path: The path to the file.

    Returns:
        True if the file matches Bazel file naming patterns, False otherwise.
    """
    basename = path.name
    EXTENSIONS = (
        # standard Bazel files
        ".bzl",
        ".bazel",
        # Starlark configuration language:
        # https://github.com/bazelbuild/bazel/commit/a0cd355347b57b17f28695a84af168f9fd200ba1
        ".scl",
        ".sky",
        # WORKSPACE.bzlmod
        ".bzlmod",
        # These aren't standard Bazel files, but some projects use these extensions
        # for Bazel files that are not expected to be read by Bazel in that
        # path, but symlinked elsewhere (e.g. build/bazel/bazel.WORKSPACE, toplevel.WORKSPACE)
        ".BUILD",
        ".WORKSPACE",
    )
    return basename in ("BUILD", "WORKSPACE") or path.suffix in EXTENSIONS


if __name__ == "__main__":
    main()
