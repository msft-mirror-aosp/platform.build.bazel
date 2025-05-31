"""Exports Windows SDK libraries and tools from the "Windows Kits\\<os major>" directory."""

load("@//build/bazel/rules:simple_toolchain.bzl", "simple_toolchain")
load("@//build/bazel/toolchains/cc:rules.bzl", "cc_toolchain_import")

package(default_visibility = ["@//build/bazel/toolchains/cc:__subpackages__"])

cc_toolchain_import(
    name = "sdk_libs_x64",
    include_paths = [
        ":include/ucrt",
        ":include/shared",
        ":include/um",
        ":include/winrt",
        ":include/cppwinrt",
    ],
    lib_search_paths = [
        ":lib/ucrt/x64",
        ":lib/um/x64",
    ],
    support_files = glob(
        [
            "include/**",
            "lib/ucrt/x64/**",
            "lib/um/x64/**",
        ],
    ),
)

simple_toolchain(
    name = "resource_compiler_toolchain_x64",
    args = ["/nologo"],
    executable = ":bin/x64/rc.exe",
    runfiles = [":bin/x64/rcdll.dll"],
)
