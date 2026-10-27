"""Exports MSVC libraries from the "VC\\Tools\\MSVC\\<version>" directory, and
the corresponding DIA sdk.
"""

load(
    "@goldfish_build//toolchains/cc:actions.bzl",
    "ASSEMBLE_ACTIONS",
)
load("@goldfish_build//toolchains/cc:rules.bzl", "cc_tool", "cc_toolchain_import")
load("@rules_cc//cc:defs.bzl", "cc_import", "cc_library")

package(default_visibility = ["@toolchain_hub//:__subpackages__"])

filegroup(
    name = "dlls_x64",
    srcs = glob(
        ["msvc/bin/Hostx64/x64/*.dll"],
        allow_empty = True,
    ),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "dlls_aarch64",
    srcs = glob(
        ["msvc_redist/arm64/Microsoft.VC*.CRT/*.dll"],
        allow_empty = True,
    ) or glob(
        ["msvc/bin/HostArm64/arm64/*.dll"],
        allow_empty = True,
    ),
    visibility = ["//visibility:public"],
)

cc_tool(
    name = "ml64",
    applied_actions = ASSEMBLE_ACTIONS,
    tool = ":msvc/bin/Hostx64/x64/ml64.exe",
)

cc_tool(
    name = "armasm64",
    applied_actions = ASSEMBLE_ACTIONS,
    tool = ":msvc/bin/Hostx64/arm64/armasm64.exe",
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
            "msvc/atlmfc/lib/x64/*.lib",
        ],
        allow_empty = True,
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

cc_toolchain_import(
    name = "msvc_runtimes_aarch64",
    include_paths = [
        ":msvc/include",
        ":msvc/atlmfc/include",
    ],
    lib_search_paths = [
        ":msvc/lib/arm64",
        ":msvc/atlmfc/lib/arm64",
    ],
    support_files = glob(
        [
            "msvc/include/**",
            "msvc/lib/arm64/**",
            "msvc/atlmfc/include/**",
            "msvc/atlmfc/lib/arm64/*.lib",
        ],
        allow_empty = True,
        exclude = [
            "msvc/include/cliext/**",
            "msvc/include/codeanalysis/**",
            "msvc/include/experimental/**",
            "msvc/include/maifest/**",
            "msvc/include/msclr/**",
            "msvc/lib/arm64/store/**",
            "msvc/lib/arm64/uwp/**",
            "msvc/lib/arm64/clang_rt*",
        ],
    ),
)

cc_import(
    name = "msdia_internal",
    hdrs = glob(
        ["ms_dia_sdk/include/*.h"],
        allow_empty = True,
    ),
    interface_library = select({
        "@platforms//cpu:aarch64": ":ms_dia_sdk/lib/arm64/diaguids.lib",
        "@platforms//cpu:x86_64": ":ms_dia_sdk/lib/amd64/diaguids.lib",
    }),
    shared_library = select({
        "@platforms//cpu:aarch64": ":ms_dia_sdk/bin/arm64/msdia140.dll",
        "@platforms//cpu:x86_64": ":ms_dia_sdk/bin/amd64/msdia140.dll",
    }),
    visibility = ["//visibility:private"],
)

cc_library(
    name = "msdia",
    includes = ["ms_dia_sdk/include"],
    deps = [":msdia_internal"],
)
