#!/usr/bin/env python3
"""
Bazel Compile Commands JSON Generator & Combiner.

This script acts as the bridge between Bazel's build actions and the Clang tooling ecosystem.
It is invoked by the Starlark aspect to capture compiler invocations and format them
into the JSON compilation database format (compile_commands.json).

Modes:
1. `generate`: Creates a single-entry JSON list for a specific C/C++ source file.
   It captures the exact flags used by Bazel, including toolchain include paths.

2. `combine`: Aggregates multiple single-entry JSON files into one large JSON list.
   Used to merge snippets from a target's dependencies or to create the final repo-wide file.

Usage:
    # Generate (Note the '--' separator which is critical for parsing):
    python3 gen_cc_snippet.py generate \
        -o out.json \
        -i source.cc \
        -- \
        /path/to/clang -c source.cc -Iheaders ...

    # Combine
    python3 gen_cc_snippet.py combine -o final.json snippet1.json snippet2.json ...
"""

import argparse
import json
import os
import shlex
import sys
from typing import List, Dict, Any
from pathlib import Path


def guess_execroot(path: Path) -> Path:
    """
    Attempts to resolve the actual Bazel execution root from within a sandbox.

    The Problem:
        When running inside a Bazel sandbox (e.g., darwin-sandbox), os.getcwd()
        returns a path inside /private/var/tmp/.../sandbox/process_wrapper/.
        However, clangd/VSCode expect paths in 'compile_commands.json' to be
        relative to the workspace root (execroot), not the ephemeral sandbox.

    The Fix:
        This function recursively traverses up the directory tree looking for
        the 'sandbox' directory, then constructs the sibling 'execroot/_main' path.

    Args:
        path: The current working directory path to start searching from.

    Returns:
        Path: The guessed path to 'execroot/_main'.
    """
    if path.name == "execroot":
        # We found the sandbox root. The execroot is usually a sibling directory.
        # Structure: .../output_base/execroot/...
        # Target:    .../output_base/
        return path / "_main"

    if path.parent == path:
        # We hit the filesystem root without finding 'sandbox'.
        # Fallback: just assume CWD is correct (e.g. 'spawn' strategy).
        return Path.cwd()

    return guess_execroot(path.parent)


def _create_parser() -> argparse.ArgumentParser:
    """Configures the argument parser for subcommands."""
    parser = argparse.ArgumentParser(
        description="Generates or combines compile_commands.json fragments."
    )
    subparsers = parser.add_subparsers(
        dest="mode", required=True, help="Operation mode"
    )

    # --- Subcommand: install ---
    install_parser = subparsers.add_parser(
        "install", help="Install the JSON to workspace."
    )
    install_parser.add_argument(
        "--input_file",
        required=True,
        help="Path to the generated JSON file in runfiles.",
    )
    install_parser.add_argument(
        "--output_base",
        required=False,
        default=guess_execroot(Path.cwd()),
        help="The bazel output base. Defaults to guessing based on CWD.",
    )

    # --- Subcommand: generate ---
    gen_parser = subparsers.add_parser("generate", help="Generate a JSON snippet.")
    gen_parser.add_argument(
        "-o", "--output_file", required=True, help="Path to the output JSON snippet."
    )
    gen_parser.add_argument(
        "-i", "--input_file", required=True, help="Path to the C/C++ source file."
    )
    gen_parser.add_argument(
        "--flags_file", help="A file containing the compiler flags, one per line."
    )

    # --- Subcommand: combine ---
    comb_parser = subparsers.add_parser(
        "combine", help="Combine multiple JSON snippets."
    )
    comb_parser.add_argument(
        "-o", "--output_file", required=True, help="Path to the output JSON file."
    )
    comb_parser.add_argument(
        "--inputs_file", help="A file with a list of json files to combine."
    )

    return parser


def _handle_generate(args: argparse.Namespace) -> None:
    """
    Writes a single compilation database entry.

    Args:
        args: Parsed arguments containing output_file, input_file, and exec_root.
        compiler_flags: The raw list of flags meant for the compiler (e.g. ['-I.', '-O2']).
    """
    compiler_flags = []
    if args.flags_file:
        with open(args.flags_file, "r") as f:
            compiler_flags = [line.strip() for line in f if line.strip()]

    # 2. Construct the full command
    # We explicitly append the source file to the compiler flags to mimic a
    # standard compiler invocation (clang++ [flags] -c source.cc).
    full_args = compiler_flags + ["-c", args.input_file]

    # 3. Create the Entry
    # 'directory': Must be the build root so relative paths in 'command' resolve.
    # 'command': We use shlex.join to properly quote arguments with spaces.
    entry = {
        "command": shlex.join(full_args),
        "file": args.input_file,
    }

    # Write out a single command_compile.json entry inside a list.
    with open(args.output_file, "w", encoding="utf-8") as f:
        json.dump([entry], f, indent=2)


def _handle_install(args: argparse.Namespace) -> None:
    """
    Copies the generated JSON file from the Bazel runfiles to the user's workspace.
    This is used when running 'bazel run //:compile_commands'.
    """
    workspace_dir = os.environ.get("BUILD_WORKSPACE_DIRECTORY")

    if not workspace_dir:
        print("Error: This script must be run via 'bazel run //...'", file=sys.stderr)
        sys.exit(1)

    source = Path(args.input_file)
    destination = Path(workspace_dir) / "compile_commands.json"

    if not source.exists():
        print(f"Error: Source file not found: {source}", file=sys.stderr)
        sys.exit(1)

    print(f"Installing {source.name} to {destination}...")
    try:
        entries = []
        with open(source, "r", encoding="utf-8") as f:
            entries = json.load(f)
            for entry in entries:
                entry["directory"] = str(args.output_base)

        with open(destination, "w", encoding="utf-8") as f:
            json.dump(entries, f, indent=2)

        # Ensure it is writable so the user can easily overwrite/delete it later
        os.chmod(destination, 0o644)
        print("Success.")
    except OSError as e:
        print(f"Error installing file: {e}", file=sys.stderr)
        sys.exit(1)


def _handle_combine(args: argparse.Namespace) -> None:
    """
    Reads multiple JSON files and merges them.
    Deduplicates exact matches (same file, same directory, same command).
    """
    combined_entries: List[Dict[str, Any]] = []
    seen_entries = set()
    inputs = []
    if args.inputs_file:
        with open(args.inputs_file, "r") as f:
            inputs = [line.strip() for line in f if line.strip()]

    for input_path in inputs:
        try:
            with open(input_path, "r", encoding="utf-8") as f:
                data = json.load(f)

                # Normalize to a list if it's a single dict
                if not isinstance(data, list):
                    data = [data]

                for entry in data:
                    # Create a hashable representation of the entry to check uniqueness.
                    # We use a tuple of sorted items to ensure dictionary order doesn't matter.
                    # (directory, command, file) is usually sufficient.
                    if entry["file"] not in seen_entries:
                        seen_entries.add(entry["file"])
                        combined_entries.append(entry)

        except (IOError, json.JSONDecodeError) as e:
            print(f"Error merging {input_path}: {e}", file=sys.stderr)
            sys.exit(1)

    with open(args.output_file, "w", encoding="utf-8") as f:
        json.dump(combined_entries, f, indent=2)


def main() -> None:
    parser = _create_parser()

    # parse_known_args is critical here!
    # It parses known flags (-o, -i, -e) and leaves the rest in 'unknown'.
    # This 'unknown' list contains the actual compiler command we need to capture.
    args = parser.parse_args()

    if args.mode == "generate":
        _handle_generate(args)
    elif args.mode == "combine":
        _handle_combine(args)
    elif args.mode == "install":
        _handle_install(args)


if __name__ == "__main__":
    main()
