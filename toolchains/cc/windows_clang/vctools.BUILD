"""Exports MSVC libraries from the "VC\\Tools\\MSVC\\<version>" directory, and
the corresponding DIA sdk.
"""

load(
    "@//build/bazel/toolchains/cc:actions.bzl",
    "ASSEMBLE_ACTIONS",
)
load("@//build/bazel/toolchains/cc:rules.bzl", "cc_tool", "cc_toolchain_import")
load("@rules_cc//cc:defs.bzl", "cc_import", "cc_library")

package(default_visibility = ["@//build/bazel/toolchains/cc:__subpackages__"])

cc_tool(
    name = "ml64",
    applied_actions = ASSEMBLE_ACTIONS,
    tool = ":msvc/bin/Hostx64/x64/ml64.exe",
)

cc_toolchain_import(
    name = "msvc_runtimes_x64",
    include_paths = [
        ":msvc/include",
        ":msvc/atlmfc/include",
    ],
    lib_search_paths = [
        ":msvc/lib/x64",
        ":msvc/atlmfc/lib/x64",
    ],
    support_files = glob(
        [
            "msvc/include/**",
            "msvc/lib/x64/**",
            "msvc/atlmfc/include/**",
            "msvc/atlmfc/lib/x64/mfc*.lib",
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
    name = "msdia_internal",
    hdrs = glob(["ms_dia_sdk/include/*.h"]),
    interface_library = select({
        "@platforms//cpu:x86_64": ":ms_dia_sdk/lib/amd64/diaguids.lib",
    }),
    shared_library = select({
        "@platforms//cpu:x86_64": ":ms_dia_sdk/bin/amd64/msdia140.dll",
    }),
    visibility = ["//visibility:private"],
)

cc_library(
    name = "msdia",
    includes = ["ms_dia_sdk/include"],
    visibility = ["//visibility:public"],
    deps = [":msdia_internal"],
)
