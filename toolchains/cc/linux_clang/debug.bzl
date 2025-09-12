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

"""GNU debug info support for ELF binaries."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

_OBJCOPY_TOOLCHAIN_TYPE = "//toolchains/cc:objcopy_toolchain_type"
_SWITCH_FLAG = "//toolchains/cc/linux_clang:generate_gnu_debug_file"

GnuDebugInfo = provider(
    doc = "Metadata for GNU debug files from ELF binaries.",
    fields = ["executable_file", "debug_file"],
)

def _gen_gnu_debug_aspect_impl(target, ctx):
    executable_file = target.files_to_run.executable or target.files.to_list()[0]  # type: File
    if hasattr(target.output_groups, "debug_file"):
        return [GnuDebugInfo(
            executable_file = executable_file,
            debug_file = target.output_groups.debug_file.to_list()[0],
        )]
    if not ctx.attr._switch_flag[BuildSettingInfo].value:
        return []
    toolchain = ctx.toolchains[_OBJCOPY_TOOLCHAIN_TYPE]
    if not toolchain:
        fail("Flag", _SWITCH_FLAG, "is enabled, but no toolchain is available for toolchain type", _OBJCOPY_TOOLCHAIN_TYPE)
    objcopy = toolchain.tool
    debug_file_name = executable_file.basename + ".debug"
    output = ctx.actions.declare_file(debug_file_name, sibling = executable_file)
    ctx.actions.run(
        mnemonic = "GnuDebugInfo",
        progress_message = "Extracting Debug Info " + output.short_path,
        outputs = [output],
        inputs = [executable_file],
        executable = objcopy.executable,
        tools = objcopy.runfiles,
        arguments = objcopy.args + ["--only-keep-debug", executable_file.path, output.path],
        env = objcopy.env,
        toolchain = _OBJCOPY_TOOLCHAIN_TYPE,
    )
    return [
        GnuDebugInfo(executable_file = executable_file, debug_file = output),
        OutputGroupInfo(debug_file = depset([output])),
    ]

gen_gnu_debug_aspect = aspect(
    doc = "Create GNU debug file for ELF binaries.",
    implementation = _gen_gnu_debug_aspect_impl,
    attrs = {
        "_switch_flag": attr.label(default = _SWITCH_FLAG),
    },
    toolchains = [config_common.toolchain_type(
        _OBJCOPY_TOOLCHAIN_TYPE,
        mandatory = False,
    )],
)
