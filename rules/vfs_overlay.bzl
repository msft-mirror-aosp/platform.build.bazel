"""Rule to generate Clang VFS overlay YAML.

The vfs_overlay rule is used to create a YAML file that maps virtual paths
(like C:/msvc/include/stdio.h) to their actual locations in the Bazel execution
root (e.g., external/vctools/msvc/include/stdio.h).

This is critical for cross-compilation environments as it:
- Provides a consistent, hermetic view of system headers.
- Handles case-sensitivity differences between file systems (e.g., building
  Windows code on Linux), ensuring that header lookups succeed regardless of
  the casing used in #include directives.

Example:
    vfs_overlay(
        name = "msvc_vfs",
        msvc_srcs = "@vctools//:all_files",
        sdk_srcs = "@windows_sdk//:all_files",
        out = "msvc_vfs.yaml",
        virtual_msvc_root = "C:/msvc",
        virtual_sdk_root = "C:/sdk",
    )
"""

def _vfs_overlay_impl(ctx):
    """Implementation of the vfs_overlay rule.

    This rule performs the following steps:
    1. Generates manifest files (text files containing lists of paths) for
       both MSVC and SDK source files.
    2. Heuristically determines the 'external root' for MSVC and SDK by
       inspecting the paths of the provided source files.
    3. Runs the generate_vfs tool to create the final YAML overlay.
    """
    output = ctx.outputs.out

    # Create manifests for MSVC and SDK files
    msvc_manifest = ctx.actions.declare_file(ctx.label.name + "_msvc_manifest.txt")
    sdk_manifest = ctx.actions.declare_file(ctx.label.name + "_sdk_manifest.txt")

    msvc_files = ctx.files.msvc_srcs
    sdk_files = ctx.files.sdk_srcs

    ctx.actions.write(
        output = msvc_manifest,
        content = "\n".join([f.path for f in msvc_files]),
    )

    ctx.actions.write(
        output = sdk_manifest,
        content = "\n".join([f.path for f in sdk_files]),
    )

    # Derive external roots from the first file in each set.
    # We expect files to be in 'external/<repo>/msvc/...' or 'external/<repo>/Include/...'
    # We want the 'external/<repo>/msvc' part for MSVC and 'external/<repo>' for SDK.

    external_msvc_root = ""
    if msvc_files:
        # File path is like: external/goldfish_build++toolchain+vctools_hermetic/msvc/include/stdio.h
        # We want: external/goldfish_build++toolchain+vctools_hermetic/msvc
        parts = msvc_files[0].path.split("/")
        if "msvc" in parts:
            idx = parts.index("msvc")
            external_msvc_root = "/".join(parts[:idx + 1])
        else:
            # Fallback to repo root
            external_msvc_root = "/".join(parts[:2])

    external_sdk_root = ""
    if sdk_files:
        # File path is like: external/goldfish_build++toolchain+windows_sdk_hermetic/Include/um/windows.h
        parts = sdk_files[0].path.split("/")
        external_sdk_root = "/".join(parts[:2])

    args = ctx.actions.args()
    args.add("--msvc-files", msvc_manifest)
    args.add("--sdk-files", sdk_manifest)
    args.add("--output", output)
    args.add("--virtual-msvc-root", ctx.attr.virtual_msvc_root)
    args.add("--external-msvc-root", external_msvc_root)
    args.add("--virtual-sdk-root", ctx.attr.virtual_sdk_root)
    args.add("--external-sdk-root", external_sdk_root)
    if ctx.attr.strip_sdk_version:
        args.add("--strip-sdk-version")

    ctx.actions.run(
        outputs = [output],
        inputs = depset(
            direct = [msvc_manifest, sdk_manifest],
            transitive = [ctx.attr.msvc_srcs.files, ctx.attr.sdk_srcs.files],
        ),
        executable = ctx.executable._tool,
        arguments = [args],
        mnemonic = "GenerateVfsOverlay",
        progress_message = "Generating Clang VFS overlay for %s" % ctx.label,
    )

    return [DefaultInfo(files = depset([output]))]

vfs_overlay = rule(
    implementation = _vfs_overlay_impl,
    attrs = {
        "msvc_srcs": attr.label(
            doc = "Filegroup containing all MSVC headers and libraries.",
            mandatory = True,
        ),
        "sdk_srcs": attr.label(
            doc = "Filegroup containing all Windows SDK headers and libraries.",
            mandatory = True,
        ),
        "out": attr.output(
            doc = "The generated YAML file.",
            mandatory = True,
        ),
        "virtual_msvc_root": attr.string(default = "C:/msvc"),
        "virtual_sdk_root": attr.string(default = "C:/sdk"),
        "strip_sdk_version": attr.bool(default = False),
        "_tool": attr.label(
            default = "//utils:generate_vfs",
            executable = True,
            cfg = "exec",
        ),
    },
)
