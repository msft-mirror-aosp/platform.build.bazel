# Copyright 2019 The Bazel Authors. All rights reserved.
# Modifications Copyright 2024 - The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Starlark rule to compile RC files on Windows."""

load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

TOOLCHAIN_TYPE = "//toolchains/cc/windows_clang:resource_compiler_toolchain_type"

def _replace_ext(n, e):
    i = n.rfind(".")
    if i > 0:
        return n[:i] + e
    else:
        return n + e

def _compile_rc(ctx, rc_toolchain, rc_file, extra_inputs):
    """Compiles a single RC file to RES."""
    out = ctx.actions.declare_file(_replace_ext(rc_file.basename, ".res"))
    ctx.actions.run(
        inputs = [rc_file] + extra_inputs,
        outputs = [out],
        executable = rc_toolchain.executable,
        tools = rc_toolchain.runfiles,
        env = rc_toolchain.env,
        arguments = rc_toolchain.args + ["/fo", out.path, rc_file.path],
        mnemonic = "WindowsRc",
        toolchain = TOOLCHAIN_TYPE,
    )
    return out

def _windows_resources_shared(ctx, label, rc_files, resources, rc_toolchain):
    if not rc_toolchain.executable:
        return [CcInfo()]

    compiled_resources = [
        _compile_rc(ctx, rc_toolchain, rc_file, resources)
        for rc_file in rc_files
    ]
    link_flags = [res.path for res in compiled_resources]
    linker_input = cc_common.create_linker_input(
        owner = label,
        additional_inputs = depset(compiled_resources),
        user_link_flags = link_flags,
    )
    linking_context = cc_common.create_linking_context(
        linker_inputs = depset([linker_input]),
    )
    return [
        DefaultInfo(files = depset(compiled_resources)),
        CcInfo(linking_context = linking_context),
    ]

def _windows_resources_impl(ctx):
    rc_toolchain = ctx.toolchains[TOOLCHAIN_TYPE].tool
    return _windows_resources_shared(ctx, ctx.label, ctx.files.rc_files, ctx.files.resources, rc_toolchain)

windows_resources = rule(
    implementation = _windows_resources_impl,
    attrs = {
        "rc_files": attr.label_list(
            mandatory = True,
            allow_files = [".rc"],
            doc = "Resource files to compile. Each file must have a different basename to avoid conflicting output files.",
        ),
        "resources": attr.label_list(
            allow_files = True,
            doc = "Additional input files that RC files reference, if any.",
        ),
    },
    fragments = ["cpp"],
    toolchains = [TOOLCHAIN_TYPE],
    provides = [DefaultInfo, CcInfo],
    exec_compatible_with = ["@platforms//os:windows"],
    doc = """Compiles Windows resources (RC files) to be embedded in the final cc_binary.

Accepts .rc files (with accompanying resources) and embeds them into the
cc_binary that depends on this target.

Example usage:

    windows_resources(
        name = "hello_resources",
        rc_files = [
            "hello.rc",
            "version.rc",
        ],
        resources = [
            "version.txt",
            "//images:app.ico",
        ],
    )

    cc_binary(
        name = "hello",
        srcs = ["main.cc"],
        deps = [":hello_resources"],
    )""",
)

def _windows_manifest_resource_impl(ctx):
    # exe or dll into which this manifest resource will be embedded.
    binary_filename = ctx.attr.binary_filename

    manifest_file = ctx.actions.declare_file(binary_filename + ".manifest")
    manifest_rc_file = ctx.actions.declare_file(binary_filename + ".manifest.rc")

    # TODO(whollins): Do we need to update the version?
    manifest_content = [
        "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>",
        "<assembly manifestVersion=\"1.0\" xmlns=\"urn:schemas-microsoft-com:asm.v1\">",
        "<assemblyIdentity type=\"win32\" name=\"{}\" version=\"1.0.0.0\"/>".format(binary_filename),
        "<application>",
        "<windowsSettings>",
        "<activeCodePage xmlns=\"http://schemas.microsoft.com/SMI/2019/WindowsSettings\">UTF-8</activeCodePage>",
        "</windowsSettings>",
        "</application>",
        "</assembly>",
    ]
    ctx.actions.write(output = manifest_file, content = "\n".join(manifest_content))

    manifest_rc_content = [
        # e.g. "1 RT_MANIFEST \"qemu-system-x86_64.exe.manifest\"",
        "1 24 \"{}\"".format(manifest_file.basename),
    ]
    ctx.actions.write(output = manifest_rc_file, content = "\n".join(manifest_rc_content))

    rc_toolchain = ctx.toolchains[TOOLCHAIN_TYPE].tool
    return _windows_resources_shared(ctx, ctx.label, [manifest_rc_file], [manifest_file], rc_toolchain)

windows_manifest_resource = rule(
    implementation = _windows_manifest_resource_impl,
    attrs = {"binary_filename": attr.string(mandatory = True)},
    fragments = ["cpp"],
    toolchains = [TOOLCHAIN_TYPE],
    provides = [DefaultInfo, CcInfo],
    exec_compatible_with = ["@platforms//os:windows"],
    doc = """Creates a compiled Windows resource file containing a manifest that sets the codepage to UTF-8""",
)
