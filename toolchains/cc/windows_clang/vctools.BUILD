"""Exports MSVC libraries from the "VC\\Tools\\MSVC\\<version>" directory, and
the corresponding DIA sdk.
"""

load("@//build/bazel/toolchains/cc:rules.bzl", "cc_toolchain_import")
load("@rules_cc//cc:defs.bzl", "cc_import")

package(default_visibility = ["@//build/bazel/toolchains/cc:__subpackages__"])

cc_toolchain_import(
    name = "msvc_runtimes_x64",
    include_paths = [
        ":msvc/include",
    ],
    lib_search_paths = [
        ":msvc/lib/x64",
    ],
    support_files = glob(
        [
            "msvc/include/**",
            "msvc/lib/x64/**",
        ],
        exclude = [
            "msvc/include/cliext/**",
            "msvc/include/codeanalysis/**",
            "msvc/include/experimental/**",
            "msvc/include/maifest/**",
            "msvc/include/msclr/**",
            "msvc/lib/x64/store/**",
            "msvc/lib/x64/uwp/**",
            "msvc/lib/x64/clang_rt*",
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
