# Copyright 2026 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Parallel Zip archive creation rule driving 7-Zip as a drop-in replacement for rules_pkg."""

load(
    "@rules_pkg//pkg:providers.bzl",
    "PackageVariablesInfo",
)

# buildifier: disable=bzl-visibility
load(
    "@rules_pkg//pkg/private:pkg_files.bzl",
    "add_label_list",
    "create_mapping_context_from_ctx",
    "write_manifest",
)

# buildifier: disable=bzl-visibility
load(
    "@rules_pkg//pkg/private:util.bzl",
    "setup_output_files",
    "substitute_package_variables",
)

_stamp_condition = Label("@rules_pkg//pkg/private:private_stamp_detect")

def _parallel_pkg_zip_impl(ctx):
    outputs, output_file, _ = setup_output_files(ctx)

    args = ctx.actions.args()
    args.add("--sevenzip", ctx.executable._sevenzip)
    args.add("-o", output_file.path)
    args.add("-d", substitute_package_variables(ctx, ctx.attr.package_dir))
    args.add("-t", str(ctx.attr.timestamp))
    args.add("-m", ctx.attr.mode)
    args.add("-c", str(ctx.attr.compression_type))
    args.add("-l", str(ctx.attr.compression_level))

    inputs = []
    if ctx.attr.stamp == 1 or (ctx.attr.stamp == -1 and ctx.attr.private_stamp_detect):
        args.add("--stamp_from", ctx.version_file.path)
        inputs.append(ctx.version_file)

    mapping_context = create_mapping_context_from_ctx(
        ctx,
        label = ctx.label,
        include_runfiles = ctx.attr.include_runfiles,
        strip_prefix = ctx.attr.strip_prefix,
        default_mode = ctx.attr.mode,
    )
    add_label_list(mapping_context, srcs = ctx.attr.srcs)

    manifest_file = ctx.actions.declare_file(ctx.label.name + ".manifest")
    inputs.append(manifest_file)
    write_manifest(ctx, manifest_file, mapping_context.content_map)
    args.add("--manifest", manifest_file.path)
    args.set_param_file_format("multiline")
    args.use_param_file("@%s")

    all_inputs = depset(direct = inputs, transitive = mapping_context.file_deps)

    ctx.actions.run(
        mnemonic = "PackageZip",
        inputs = all_inputs,
        executable = ctx.executable._build_zip,
        tools = [ctx.attr._sevenzip[DefaultInfo].files_to_run],
        arguments = [args],
        outputs = [output_file],
        env = {
            "LANG": "en_US.UTF-8",
            "LC_CTYPE": "UTF-8",
            "PYTHONIOENCODING": "UTF-8",
            "PYTHONUTF8": "1",
            "TZ": "UTC",
        },
    )
    return [
        DefaultInfo(
            files = depset([output_file]),
            runfiles = ctx.runfiles(files = outputs),
        ),
    ]

parallel_pkg_zip_impl = rule(
    implementation = _parallel_pkg_zip_impl,
    attrs = {
        "srcs": attr.label_list(
            doc = "List of files that should be included in the archive.",
            allow_files = True,
        ),
        "mode": attr.string(
            doc = "The default mode for all files in the archive.",
            default = "0555",
        ),
        "package_dir": attr.string(
            doc = "Prefix to prepend to all paths written.",
            default = "/",
        ),
        "strip_prefix": attr.string(),
        "include_runfiles": attr.bool(),
        "timestamp": attr.int(
            doc = "Unix epoch timestamp for files.",
            default = 315532800,
        ),
        "compression_level": attr.int(
            default = 6,
            doc = "Compression level (0-9). 0 skips compression, 1 is fastest.",
        ),
        "compression_type": attr.string(
            default = "deflated",
            doc = "Compression type.",
            values = ["deflated", "lzma", "bzip2", "stored"],
        ),
        "out": attr.output(
            doc = "Output file name. Default: name + '.zip'.",
            mandatory = True,
        ),
        "package_file_name": attr.string(),
        "package_variables": attr.label(
            providers = [PackageVariablesInfo],
        ),
        "stamp": attr.int(
            default = 0,
        ),
        "allow_duplicates_with_different_content": attr.bool(
            default = True,
        ),
        "private_stamp_detect": attr.bool(default = False),
        "_build_zip": attr.label(
            default = Label("//rules:parallel_zip"),
            cfg = "exec",
            executable = True,
            allow_files = True,
        ),
        "_sevenzip": attr.label(
            default = Label("@sevenzip//:7za"),
            cfg = "exec",
            executable = True,
            allow_files = True,
        ),
    },
)

def parallel_pkg_zip(name, out = None, **kwargs):
    """Creates a .zip file using 7-Zip as a drop-in replacement for rules_pkg pkg_zip.

    Args:
        name: Name of target.
        out: Output file name. Default: name + '.zip'.
        **kwargs: Forwarded to parallel_pkg_zip_impl.
    """
    if not out:
        out = name + ".zip"
    parallel_pkg_zip_impl(
        name = name,
        out = out,
        private_stamp_detect = select({
            _stamp_condition: True,
            "//conditions:default": False,
        }),
        **kwargs
    )
