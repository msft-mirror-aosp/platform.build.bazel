"""Exports MSVC libraries from the "VC\\Tools\\MSVC\\<version>" directory."""

load("@//build/bazel/toolchains/cc:rules.bzl", "cc_toolchain_import")

package(default_visibility = ["@//build/bazel/toolchains/cc:__subpackages__"])

cc_toolchain_import(
    name = "msvc_runtimes_x64",
    include_paths = [
        ":include",
    ],
    lib_search_paths = [
        ":lib/x64",
    ],
    support_files = glob(
        [
            "include/**",
            "lib/x64/**",
        ],
        exclude = [
            "lib/x64/store/**",
            "lib/x64/uwp/**",
        ],
    ),
)
