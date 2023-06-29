"""Exports Windows SDK libraries from the "Windows Kits\\<os major>" directory."""

load("@//build/bazel/toolchains/cc:rules.bzl", "cc_toolchain_import")

package(default_visibility = ["@//build/bazel/toolchains/cc:__subpackages__"])

cc_toolchain_import(
    name = "sdk_libs_x64",
    include_paths = [
        ":include/%{sdk_version}/ucrt",
        ":include/%{sdk_version}/shared",
        ":include/%{sdk_version}/um",
        ":include/%{sdk_version}/winrt",
        ":include/%{sdk_version}/cppwinrt",
    ],
    lib_search_paths = [
        ":lib/%{sdk_version}/ucrt/x64",
        ":lib/%{sdk_version}/um/x64",
    ],
    support_files = glob(
        [
            "include/%{sdk_version}/**",
            "lib/%{sdk_version}/ucrt/x64/**",
            "lib/%{sdk_version}/um/x64/**",
        ],
    ),
)
