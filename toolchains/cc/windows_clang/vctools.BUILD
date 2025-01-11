"""Exports MSVC libraries from the "VC\\Tools\\MSVC\\<version>" directory."""

load("@//build/bazel/toolchains/cc:rules.bzl", "cc_toolchain_import")
load("@rules_cc//cc:defs.bzl", "cc_import")

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
            "include/cliext/**",
            "include/codeanalysis/**",
            "include/experimental/**",
            "include/maifest/**",
            "include/msclr/**",
            "lib/x64/store/**",
            "lib/x64/uwp/**",
            "lib/x64/clang_rt*",
        ],
    ),
)

cc_import(
    name = "msdia",
    hdrs = glob(["ms_dia_sdk/include/*.h"]),
    interface_library = select({
        "@platforms//cpu:x86_64": ":ms_dia_sdk/lib/amd64/diaguids.lib",
    }),
    shared_library = select({
        "@platforms//cpu:x86_64": ":ms_dia_sdk/bin/amd64/msdia140.dll",
    }),
    visibility = ["//visibility:public"],
)
