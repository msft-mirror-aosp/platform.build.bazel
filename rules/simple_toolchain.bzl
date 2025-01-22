# Copyright 2021 - The Android Open Source Project
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

"""A toolchain rule that describes a single generic tool with runfiles.

Reducing the boilerplate of new toolchain rules when all you need is just a tool.

Usage:

    load(":simple_toolchain.bzl", "simple_toolchain")

    simple_toolchain(
        name = "my_tool",
        args = ["--my_flag", ...],
        env = {
            "var1": "val1",
            ...
        },
        executable = "//label/of:my_tool",
        runfiles = ["//label/of:runfiles", ...],
    )

    toolchain(
        name = "my_tool_toolchain",
        exec_compatible_with = [
            # Add constraints here, if applicable.
        ],
        target_compatible_with = [
            # Add constraints here, if applicable.
        ],
        toolchain = ":my_tool",
        toolchain_type = "//label/of/your:toolchain_type",
    )
"""

SimpleToolInfo = provider(
    doc = "Toolchain info for a single executable tool.",
    fields = {
        "args": "Toolchain level arguments.",
        "env": "Toolchain level environment variables.",
        "executable": "The tool executable",
        "runfiles": "Support files needed by the tool at runtime",
    },
)

def _simple_toolchain_impl(ctx):
    args = [ctx.expand_location(a, targets = ctx.attr.runfiles) for a in ctx.attr.args]
    env = {k: ctx.expand_location(v, targets = ctx.attr.runfiles) for k, v in ctx.attr.env.items()}
    toolchain_info = platform_common.ToolchainInfo(
        tool = SimpleToolInfo(
            args = args,
            env = env,
            executable = ctx.file.executable,
            runfiles = ctx.files.runfiles,
        ),
    )
    return [toolchain_info]

simple_toolchain = rule(
    implementation = _simple_toolchain_impl,
    doc = "A toolchain rule that describes a single generic tool.",
    attrs = {
        "args": attr.string_list(doc = "Toolchain level arguments, subject to location expansion."),
        "env": attr.string_dict(doc = "Toolchain level environment variables, where values are subject to location expansion."),
        "executable": attr.label(
            doc = "The tool to run",
            executable = True,
            allow_single_file = True,
            mandatory = True,
            cfg = "exec",
        ),
        "runfiles": attr.label_list(
            doc = "Files required at runtime of the tool.",
            allow_files = True,
            cfg = "exec",
        ),
    },
)
