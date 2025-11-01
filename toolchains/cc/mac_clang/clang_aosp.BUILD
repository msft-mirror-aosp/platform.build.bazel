# Standalone clang for AOSP that can be used to cross compile from macos->linux arm
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@goldfish_build//rules:simple_toolchain.bzl", "simple_toolchain")
load(
    "@goldfish_build//toolchains/cc:actions.bzl",
    "ARCHIVER_ACTIONS",
    "ASSEMBLE_ACTIONS",
    "CPP_COMPILE_ACTIONS",
    "C_COMPILE_ACTIONS",
    "LINK_ACTIONS",
    "LTO_BACKEND_ACTIONS",
    "LTO_INDEX_ACTIONS",
    "OBJC_COMPILE_ACTIONS",
)
load(
    "@goldfish_build//toolchains/cc:rules.bzl",
    "cc_tool",
    "cc_toolchain_import",
)

package(default_visibility = ["@toolchain_hub//:__subpackages__"])

filegroup(
    name = "llvm_cov",
    srcs = ["bin/llvm-cov"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "llvm_profdata",
    srcs = ["bin/llvm-profdata"],
    visibility = ["//visibility:public"],
)

cc_tool(
    name = "clang",
    applied_actions = C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + ASSEMBLE_ACTIONS + LINK_ACTIONS + LTO_BACKEND_ACTIONS + LTO_INDEX_ACTIONS,
    runfiles = glob(
        [
            "bin/clang*",
            "bin/*lld",
        ],
        exclude = [
            "bin/clang-check",
            "bin/clangd",
            "bin/*clang-format",
            "bin/clang-tidy*",
        ],
    ) + ["bin/lld-link"],
    tool = ":bin/clang",
)

cc_tool(
    name = "archiver",
    applied_actions = ARCHIVER_ACTIONS,
    tool = ":bin/llvm-ar",
)

cc_tool(
    name = "strip",
    applied_actions = [ACTION_NAMES.strip],
    runfiles = [":bin/llvm-objcopy"],
    tool = ":bin/llvm-strip",
)

cc_toolchain_import(
    name = "compiler_hdrs",
    include_paths = glob(
        [
            "lib/clang/*/include",
        ],
        exclude_directories = 0,
    ),
    support_files = glob(
        [
            "lib/clang/*/include/**",
            "lib/clang/*/share/**",
        ],
    ),
)

simple_toolchain(
    name = "objcopy",
    executable = ":bin/llvm-objcopy",
)
