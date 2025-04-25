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

load("@//build/bazel/toolchains/cc/linux_clang:debug.bzl", "GnuDebugInfo", "gen_gnu_debug_aspect")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

_OBJCOPY_TOOLCHAIN_TYPE = "@//build/bazel/toolchains/cc:objcopy_toolchain_type"
_SWITCH_FLAG = "@//build/bazel/toolchains/cc:allow_strip"

def _strip_aspect_impl(target, ctx):
    executable_file = target.files_to_run.executable or target.files.to_list()[0]  # type: File
    debug_file = None
    if GnuDebugInfo in target:
        executable_file = target[GnuDebugInfo].executable_file  # type: File
        debug_file = target[GnuDebugInfo].debug_file  # type: File
    if not ctx.attr._switch_flag[BuildSettingInfo].value:
        return [OutputGroupInfo(stripped_file = depset([executable_file]))]
    toolchain = ctx.toolchains[_OBJCOPY_TOOLCHAIN_TYPE]
    if not toolchain:
        fail("Flag", _SWITCH_FLAG, "is enabled, but no toolchain is available for toolchain type", _OBJCOPY_TOOLCHAIN_TYPE)
    output_name = "_stripped/" + executable_file.basename
    output = ctx.actions.declare_file(output_name)
    objcopy = toolchain.tool
    args = list(objcopy.args)
    inputs = [executable_file]
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
        arguments = args + ["--strip-all", executable_file.path, output.path],
        env = objcopy.env,
        toolchain = _OBJCOPY_TOOLCHAIN_TYPE,
    )
    return [OutputGroupInfo(stripped_file = depset([output]))]

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
