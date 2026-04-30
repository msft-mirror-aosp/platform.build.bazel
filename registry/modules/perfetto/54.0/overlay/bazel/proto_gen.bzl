# Copyright (C) 2019 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""This file is an overlay of `bazel/proto_gen.bzl` from the Perfetto repository.

It is used to override the original file in the `@perfetto` repository to ensure
compatibility with modern Bazel (e.g., Bazel 9).

Main differences from upstream:
1. Added `load("@com_google_protobuf//bazel/common:proto_info.bzl", "ProtoInfo")` to resolve implicit symbol resolution issues.
2. Changed `cfg = "host"` to `cfg = "exec"` in the `proto_gen` rule attributes.
"""

load("@com_google_protobuf//bazel/common:proto_info.bzl", "ProtoInfo")

def _proto_gen_impl(ctx):
    proto_src = [
        f
        for dep in ctx.attr.deps
        for f in dep[ProtoInfo].direct_sources
    ]
    includes = [
        f
        for dep in ctx.attr.deps
        for f in dep[ProtoInfo].transitive_sources.to_list()
    ]
    proto_paths = [
        f
        for dep in ctx.attr.deps
        for f in dep[ProtoInfo].transitive_proto_path.to_list()
    ]

    out_dir = ctx.bin_dir.path
    strip_base_path = ""
    if ctx.attr.root != "//":
        strip_base_path = ctx.label.package + "/"
    elif ctx.label.workspace_root:
        if not ctx.label.workspace_root.startswith("../"):
            out_dir += "/" + ctx.label.workspace_root
        strip_base_path = ctx.label.workspace_root + "/"

    out_files = []
    suffix = ctx.attr.suffix
    for src in proto_src:
        base_path = src.path[:-len(".proto")]
        if base_path.startswith(strip_base_path):
            base_path = base_path[len(strip_base_path):]
        out_files.append(ctx.actions.declare_file(base_path + ".%s.h" % suffix))
        out_files.append(ctx.actions.declare_file(base_path + ".%s.cc" % suffix))

    arguments = [
        "--proto_path=" + proto_path
        for proto_path in proto_paths
    ]

    plugin_deps = []
    if ctx.attr.plugin:
        wrap_arg = ctx.attr.wrapper_namespace
        arguments += [
            "--plugin=protoc-gen-plugin=" + ctx.executable.plugin.path,
            "--plugin_out=wrapper_namespace=" + wrap_arg + ":" + out_dir,
        ]
        plugin_deps.append(ctx.executable.plugin)
    else:
        arguments.append(
            "--cpp_out=lite=true:" + out_dir,
        )

    arguments += [src.path for src in proto_src]
    ctx.actions.run(
        inputs = proto_src + includes + plugin_deps,
        tools = plugin_deps,
        outputs = out_files,
        mnemonic = "PerfettoProtoGen",
        executable = ctx.executable.protoc,
        arguments = arguments,
    )
    cc_files = depset([f for f in out_files if f.path.endswith(".cc")])
    h_files = depset([f for f in out_files if f.path.endswith(".h")])
    return [
        DefaultInfo(files = cc_files),
        OutputGroupInfo(
            cc = cc_files,
            h = h_files,
        ),
    ]

proto_gen = rule(
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
            allow_empty = False,
            providers = [ProtoInfo],
        ),
        "plugin": attr.label(
            executable = True,
            mandatory = False,
            cfg = "exec",
        ),
        "wrapper_namespace": attr.string(
            mandatory = False,
            default = "",
        ),
        "suffix": attr.string(
            mandatory = True,
        ),
        "protoc": attr.label(
            executable = True,
            cfg = "exec",
        ),
        "root": attr.string(
            mandatory = False,
            default = "//",
        ),
    },
    implementation = _proto_gen_impl,
)

def _proto_descriptor_gen_impl(ctx):
    descriptors = [
        f
        for dep in ctx.attr.deps
        for f in dep[ProtoInfo].transitive_descriptor_sets.to_list()
    ]
    ctx.actions.run_shell(
        inputs = descriptors,
        outputs = ctx.outputs.outs,
        mnemonic = "PerfettoProtoDescriptorGen",
        command = "cat %s > %s" % (
            " ".join([f.path for f in descriptors]),
            ctx.outputs.outs[0].path,
        ),
    )

proto_descriptor_gen = rule(
    implementation = _proto_descriptor_gen_impl,
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
            allow_empty = False,
            providers = [ProtoInfo],
        ),
        "outs": attr.output_list(mandatory = True),
    },
)
