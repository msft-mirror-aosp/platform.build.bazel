"""Exports Windows SDK libraries and tools from the "Windows Kits\\<os major>" directory."""

load("@goldfish_build//rules:simple_toolchain.bzl", "simple_toolchain")
load("@goldfish_build//toolchains/cc:rules.bzl", "cc_toolchain_import")

package(default_visibility = ["@toolchain_hub//:__subpackages__"])

filegroup(
    name = "dlls",
    srcs = glob(
        ["Redist/ucrt/DLLs/x64/*.dll"],
        allow_empty = True,
    ),
    visibility = ["//visibility:public"],
)

cc_toolchain_import(
    name = "sdk_libs_x64",
    include_paths = [
        ":Include/ucrt",
        ":Include/shared",
        ":Include/um",
        ":Include/winrt",
        ":Include/cppwinrt",
    ],
    lib_search_paths = [
        ":Lib/ucrt/x64",
        ":Lib/um/x64",
    ],
    support_files = glob(
        [
            "Include/**",
            "Lib/ucrt/x64/**",
            "Lib/um/x64/**",
        ],
        allow_empty = True,
    ),
)

simple_toolchain(
    name = "resource_compiler_toolchain_x64",
    args = ["/nologo"],
    executable = ":bin/x64/rc.exe",
    runfiles = [":bin/x64/rcdll.dll"],
)
