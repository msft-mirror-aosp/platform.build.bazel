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

"""Universal stripping support."""

# This aspect replaces the strip action from cc_binary for 2 reasons:
# 1. It supports any target that produces executables (e.g. rust_binary), to
#    make sure all released artifacts receives the same treatment.
# 2. It integrates with other aspects to add debug link if applicable.

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("debug.bzl", "DebugSymbolsSetInfo", "gen_gnu_debug_aspect", "is_elf_binary")

_OBJCOPY_TOOLCHAIN_TYPE = "//toolchains/cc:objcopy_toolchain_type"
_SWITCH_FLAG = "//rules/native:allow_strip"

StrippedBinaryInfo = provider(
    doc = "Metadata for stripped binary.",
    fields = ["stripped", "unstripped"],
)

StrippedBinarySetInfo = provider(
    doc = "A depset of StrippedBinaryInfo.",
    fields = ["binaries"],
)

def _strip_aspect_impl(target, ctx):
    if target.files_to_run.executable:
        binaries = [target.files_to_run.executable]
    else:
        binaries = [f for f in target.files.to_list() if is_elf_binary(f)]

    if not ctx.attr._switch_flag[BuildSettingInfo].value:
        return [StrippedBinarySetInfo(
            binaries = depset([
                StrippedBinaryInfo(stripped = f, unstripped = f)
                for f in binaries
            ]),
        )]

    toolchain = ctx.toolchains[_OBJCOPY_TOOLCHAIN_TYPE]
    if not toolchain:
        fail("Flag", _SWITCH_FLAG, "is enabled, but no toolchain is available for toolchain type", _OBJCOPY_TOOLCHAIN_TYPE)

    debug_file_lookup = {}
    if DebugSymbolsSetInfo in target and target[DebugSymbolsSetInfo].gnu:
        for gnu in target[DebugSymbolsSetInfo].gnu.to_list():
            debug_file_lookup[gnu.executable_file] = gnu.debug_file

    strip_info = []
    for binary in binaries:
        output_name = "_stripped/" + binary.basename
        output = ctx.actions.declare_file(output_name)
        objcopy = toolchain.tool
        args = list(objcopy.args)
        inputs = [binary]
        debug_file = debug_file_lookup.get(binary)
        if debug_file:
            args.append("--add-gnu-debuglink={}".format(debug_file.path))
            inputs.append(debug_file)
        ctx.actions.run(
            mnemonic = "Strip",
            progress_message = "Stripping " + output.short_path,
            outputs = [output],
            inputs = inputs,
            executable = objcopy.executable,
            tools = objcopy.runfiles,
            arguments = args + ["--strip-all", binary.path, output.path],
            env = objcopy.env,
            toolchain = _OBJCOPY_TOOLCHAIN_TYPE,
        )
        strip_info.append(StrippedBinaryInfo(
            stripped = output,
            unstripped = binary,
        ))

    return [StrippedBinarySetInfo(binaries = depset(strip_info))]

strip_aspect = aspect(
    doc = """Create a stripped binary and add it to output group 'stripped_file'.

    If a GNU debug file can be created by invoking the "gen_gnu_debug" aspect, a
    debug link will also be added to the output pointing to the debug file.

    If the switch flag {} is disabled, the stripped binary will be the same as
    the input executable.
    """.format(_SWITCH_FLAG),
    implementation = _strip_aspect_impl,
    attrs = {
        "_switch_flag": attr.label(default = _SWITCH_FLAG),
    },
    toolchains = [config_common.toolchain_type(
        _OBJCOPY_TOOLCHAIN_TYPE,
        mandatory = False,
    )],
    requires = [gen_gnu_debug_aspect],
)
