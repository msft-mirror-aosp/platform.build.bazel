# Toolchain definition for Linux ARM64 Clang

load(
    "@goldfish_build//toolchains/cc:rules.bzl",
    "cc_toolchain_config",
    "cc_toolchain_dynamic_runtime",
)
load("@goldfish_build//toolchains/cc/linux_arm64_clang:features.bzl", "cc_features")
load("@rules_cc//cc:defs.bzl", "cc_toolchain")

package(default_visibility = ["//visibility:public"])

cc_features(
    name = "arm64_linux_features",
)

filegroup(
    name = "mac_arm64_all_files",
    srcs = [
        ":mac_arm64_linux_config",
        "@goldfish_build//toolchains/cc:empty",
    ] + [
        "@clang_mac_aosp//:archiver",
        "@clang_mac_aosp//:clang",
        "@clang_mac_aosp//:objcopy",
        "@clang_mac_aosp//:strip",
    ],
)

filegroup(
    name = "lin_arm64_all_files",
    srcs = [
        ":lin_arm64_linux_config",
        "@goldfish_build//toolchains/cc:empty",
    ] + [
        "@clang_linux_x64//:archiver",
        "@clang_linux_x64//:clang",
        "@clang_linux_x64//:objcopy",
        "@clang_linux_x64//:strip",
    ],
)

# 1. This list is for the TARGET configuration (e.g., your Linux binary).
#    It's used by cc_toolchain_dynamic_runtime.
_runtime_libs_for_target = [
    "@arm_sysroot//:libstdcxx",
    "@arm_sysroot//:libs",
]

# Host configurations
_all_imports_for_macos = _runtime_libs_for_target + ["@clang_mac_aosp//:compiler_hdrs"]

_all_imports_for_linux = _runtime_libs_for_target + ["@clang_linux_x64//:compiler_hdrs"]

cc_toolchain_dynamic_runtime(
    name = "arm64_dynamic_runtime",
    libs = _runtime_libs_for_target,
)

cc_features(
    name = "mac_arm64_features",
    assembler_flags = ["--target=aarch64-none-linux-gnu"],
    cc_only_link_flags = ["-lstdc++"],
    compile_flags = [
        "--target=aarch64-none-linux-gnu",
        "--gcc-toolchain=external/goldfish_build++toolchain+arm_sysroot",
        "-Wall",
        "-Wthread-safety",
        "-fstack-protector-strong",
        "-fcolor-diagnostics",
    ],
    cxx_flags = ["-std=c++26"],
    link_flags = [
        "--gcc-toolchain=external/goldfish_build++toolchain+arm_sysroot",
        "-fuse-ld=lld",
        "-Wno-unused-command-line-argument",
        "-Wl,--as-needed",
        "-lm",
        "-ldl",
        "-Wl,--no-as-needed",
    ],
    toolchain_imports = _all_imports_for_macos,
)

cc_features(
    name = "lin_arm64_features",
    assembler_flags = ["--target=aarch64-none-linux-gnu"],
    cc_only_link_flags = ["-lstdc++"],
    compile_flags = [
        "--target=aarch64-none-linux-gnu",
        "--gcc-toolchain=external/goldfish_build++toolchain+arm_sysroot",
        "-Wall",
        "-Wthread-safety",
        "-fstack-protector-strong",
        "-fcolor-diagnostics",
    ],
    cxx_flags = ["-std=c++26"],
    link_flags = [
        "--gcc-toolchain=external/goldfish_build++toolchain+arm_sysroot",
        "-fuse-ld=lld",
        "-Wno-unused-command-line-argument",
        "-Wl,--as-needed",
        "-lm",
        "-ldl",
        "-Wl,--no-as-needed",
    ],
    toolchain_imports = _all_imports_for_linux,
)

cc_toolchain_config(
    name = "mac_arm64_linux_config",
    cc_features = ":mac_arm64_features",
    cc_tools = [
        "@clang_mac_aosp//:clang",
        "@clang_mac_aosp//:archiver",
        "@clang_mac_aosp//:strip",
        "@clang_mac_aosp//:clang-tidy",
    ],
    compiler_name = "clang",
    identifier = "linux_clang_arm64",
    sysroot = "@arm_sysroot//:arm_sysroot",
    target_cpu = "aarch64",
    toolchain_imports = _all_imports_for_macos,
)

cc_toolchain(
    name = "mac_arm64",
    all_files = ":mac_arm64_all_files",
    ar_files = "@clang_mac_aosp//:archiver",
    as_files = "@clang_mac_aosp//:clang",
    compiler_files = ":mac_arm64_linux_config",
    dwp_files = "@goldfish_build//toolchains/cc:empty",
    dynamic_runtime_lib = ":arm64_dynamic_runtime",
    linker_files = ":mac_arm64_linux_config",
    objcopy_files = "@clang_mac_aosp//:objcopy",
    static_runtime_lib = "@goldfish_build//toolchains/cc:empty",
    strip_files = "@clang_mac_aosp//:strip",
    supports_param_files = True,
    toolchain_config = ":mac_arm64_linux_config",
)

toolchain(
    name = "mac_arm64_linux_toolchain",
    exec_compatible_with = [
        "@platforms//os:macos",
        "@bazel_tools//tools/cpp:clang",
    ],
    target_compatible_with = [
        "@platforms//cpu:aarch64",
        "@platforms//os:linux",
    ],
    toolchain = ":mac_arm64",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

## -- Linux variant --

cc_toolchain_config(
    name = "lin_arm64_linux_config",
    cc_features = ":lin_arm64_features",
    cc_tools = [
        "@clang_linux_x64//:clang",
        "@clang_linux_x64//:archiver",
        "@clang_linux_x64//:strip",
        "@clang_linux_x64//:clang-tidy",
    ],
    compiler_name = "clang",
    identifier = "linux_clang_arm64",
    sysroot = "@arm_sysroot//:arm_sysroot",
    target_cpu = "aarch64",
    toolchain_imports = _all_imports_for_linux,
)

cc_toolchain(
    name = "lin_arm64",
    all_files = ":lin_arm64_all_files",
    ar_files = "@clang_linux_x64//:archiver",
    as_files = "@clang_linux_x64//:clang",
    compiler_files = ":lin_arm64_linux_config",
    dwp_files = "@goldfish_build//toolchains/cc:empty",
    dynamic_runtime_lib = ":arm64_dynamic_runtime",
    linker_files = ":lin_arm64_linux_config",
    objcopy_files = "@clang_linux_x64//:objcopy",
    static_runtime_lib = "@goldfish_build//toolchains/cc:empty",
    strip_files = "@clang_linux_x64//:strip",
    supports_param_files = True,
    toolchain_config = ":lin_arm64_linux_config",
)

toolchain(
    name = "lin_arm64_linux_toolchain",
    exec_compatible_with = [
        "@platforms//os:linux",
        "@bazel_tools//tools/cpp:clang",
    ],
    target_compatible_with = [
        "@platforms//cpu:aarch64",
        "@platforms//os:linux",
    ],
    toolchain = ":lin_arm64",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)
