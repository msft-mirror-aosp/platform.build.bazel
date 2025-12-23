# Copyright 2025 - The Android Open Source Project
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

"""Rules for post-processing native binaries."""

load("debug.bzl", "DebugSymbolsSetInfo", "collect_pdb_aspect", "gen_dsym_aspect", "gen_gnu_debug_aspect")
load("strip.bzl", "StrippedBinarySetInfo", "strip_aspect")

TransformedFilesInfo = provider(
    doc = """Stores a map that corresponds src files to their transformed results.

    This is useful in consumers of the target to remap files.
    """,
    fields = {
        "mapping": "A dict mapping origin files to a list of transformed files. Type: dict[File, list[File]]",
        "original": "A dict mapping the transformed files in the mapping dict to their original files, if not the same.",
    },
)

def _symbol_collector():
    return struct(
        files = [],
        mapping = {},
        original = {},
    )

def _add_symbols(collector, executable_file, original_executable_file, symbol_files):
    for symbol_file in symbol_files:
        if not symbol_file:
            continue
        collector.files.append(symbol_file)
        collector.mapping.setdefault(executable_file, []).append(symbol_file)
        if original_executable_file and executable_file != original_executable_file:
            collector.original[symbol_file] = original_executable_file

def _native_symbols_impl(ctx):
    symbol_packages = [t[DebugSymbolsSetInfo] for t in ctx.attr.srcs if DebugSymbolsSetInfo in t]
    collector = _symbol_collector()
    for package in symbol_packages:
        if package.dsym:
            for dsym in package.dsym.to_list():
                _add_symbols(collector, dsym.executable_file, dsym.original_executable_file, [dsym.dsym_bundle])
        if package.gnu:
            for gnu in package.gnu.to_list():
                _add_symbols(collector, gnu.executable_file, gnu.original_executable_file, [gnu.debug_file, gnu.dwp_file])
        if package.pdb:
            for pdb in package.pdb.to_list():
                _add_symbols(collector, pdb.executable_file, pdb.original_executable_file, [pdb.pdb_file])

    return [
        DefaultInfo(files = depset(collector.files)),
        TransformedFilesInfo(mapping = collector.mapping, original = collector.original),
    ]

native_symbols = rule(
    implementation = _native_symbols_impl,
    doc = """Expose native symbols from providers and output groups.

    It relies on the binary rules and aspects to create those symbols.
    """,
    attrs = {
        "srcs": attr.label_list(
            doc = "The binary targets to inspect.",
            mandatory = True,
            allow_empty = False,
            aspects = [
                gen_dsym_aspect,
                gen_gnu_debug_aspect,
                collect_pdb_aspect,
            ],
        ),
    },
    provides = [TransformedFilesInfo],
)

def _stripped_binaries_impl(ctx):
    strip_info_set = [t[StrippedBinarySetInfo] for t in ctx.attr.srcs if StrippedBinarySetInfo in t]
    stripped_files = []
    mapping = {}
    for strip_info in strip_info_set:
        for binary in strip_info.binaries.to_list():
            stripped_files.append(binary.stripped)
            mapping[binary.unstripped] = [binary.stripped]

    return [
        DefaultInfo(files = depset(stripped_files)),
        TransformedFilesInfo(mapping = mapping, original = None),
    ]

stripped_binaries = rule(
    implementation = _stripped_binaries_impl,
    doc = """Strip binaries.

    It invokes an aspect to strip each binary, and exposes the result.
    """,
    attrs = {
        "srcs": attr.label_list(
            doc = "The binaries to strip.",
            mandatory = True,
            allow_files = True,
            allow_empty = False,
            aspects = [strip_aspect],
        ),
    },
    provides = [TransformedFilesInfo],
)
