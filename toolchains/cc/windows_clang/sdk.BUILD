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

_support_files = [
    "include/**",
    "lib/ucrt/x64/**",
    "lib/um/x64/**",
]

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
    # Bazel 9.0.0 has changed the behaviour of checking that included headers are in the dependencies on Windows - it now seems to require the exact case to match (perhaps a bug).
    # To work around this, we add alternative file names to the dependencies here.
    # The majority of "errors" are where the header file contains uppers but the include is all lower.
    # There are additionally just a few cases where the include still contains uppers and doesn't match the actual filename.
    support_files = glob(
        _support_files,
        allow_empty = True,
    ) + [x.lower() for x in glob(
        _support_files,
        allow_empty = True,
    ) if not x.islower()] + [
        "include/shared/BaseTsd.h",
        "include/um/DSound.h",
        "include/um/Ole2.h",
        "include/um/OleCtl.h",
        "include/shared/WlanTypes.h",
        "include/um/Tlhelp32.h",
        "include/shared/SpecStrings.h",
        "include/um/OCIdl.h",
        "include/um/Wbemidl.h",
    ],
)

simple_toolchain(
    name = "resource_compiler_toolchain_x64",
    args = ["/nologo"],
    executable = ":bin/x64/rc.exe",
    runfiles = [":bin/x64/rcdll.dll"],
)
