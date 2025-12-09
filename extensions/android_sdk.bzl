"""Defines a module extension to create repos for android sdk on different platforms
"""

load("@bazel_tools//tools/build_defs/repo:local.bzl", "new_local_repository")

_BUILD = """
filegroup(
    name = "sdkhome",
    srcs = glob([
        "platform-tools/**",
        "build-tools/**",
    ]),
    visibility = ["//visibility:public"],
)
"""

def _android_sdk_impl(module_ctx):
    """Implementation of the android_sdk module extension."""

    new_local_repository(
        name = "sdk_linux",
        build_file_content = _BUILD,
        path = "prebuilts/android/android-sdk/linux",
    )

    new_local_repository(
        name = "sdk_macosx",
        build_file_content = _BUILD,
        path = "prebuilts/android/android-sdk/macosx",
    )

    new_local_repository(
        name = "sdk_windows",
        build_file_content = _BUILD,
        path = "prebuilts/android/android-sdk/windows",
    )

    return module_ctx.extension_metadata(root_module_direct_deps = "all", root_module_direct_dev_deps = [], reproducible = True)

android_sdk = module_extension(
    implementation = _android_sdk_impl,
    tag_classes = {},
)
