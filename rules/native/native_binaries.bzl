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

load("@//build/bazel/toolchains/cc/linux_clang:debug.bzl", "GnuDebugInfo", "gen_gnu_debug_aspect")
load("@//build/bazel/toolchains/cc/mac_clang:dsym.bzl", "AppleDsymInfo", "gen_dsym_aspect")
load("@rules_cc//cc/common:debug_package_info.bzl", "DebugPackageInfo")

TransformedFilesInfo = provider(
    doc = """Stores a map that corresponds src files to their transformed results.

    This is useful in consumers of the target to remap files.
    """,
    fields = ["mapping"],
)

def _native_symbols_impl(ctx):
    symbol_files = []
    mapping = {}
    for binary_target in ctx.attr.srcs:
        executable_file = binary_target.files_to_run.executable or binary_target.files.to_list()[0]
        symbol_file = []
        if AppleDsymInfo in binary_target:
            symbol_file = [binary_target[AppleDsymInfo].dsym_bundle]
        elif OutputGroupInfo in binary_target and hasattr(binary_target[OutputGroupInfo], "pdb_file"):
            symbol_file = binary_target[OutputGroupInfo].pdb_file.to_list()
        elif GnuDebugInfo in binary_target:
            symbol_file = [binary_target[GnuDebugInfo].debug_file]
        if DebugPackageInfo in binary_target and binary_target[DebugPackageInfo].dwp_file:
            symbol_file.append(binary_target[DebugPackageInfo].dwp_file)
        symbol_files.extend(symbol_file)
        if symbol_file:
            mapping[executable_file] = symbol_file
    return [DefaultInfo(files = depset(symbol_files)), TransformedFilesInfo(mapping = mapping)]

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
            aspects = [gen_dsym_aspect, gen_gnu_debug_aspect],
        ),
    },
    provides = [TransformedFilesInfo],
)
