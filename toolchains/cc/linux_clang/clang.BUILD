load(
    "@//build/bazel/toolchains/cc:actions.bzl",
    "ASSEMBLE_ACTIONS",
    "CPP_COMPILE_ACTIONS",
    "C_COMPILE_ACTIONS",
    "LINK_ACTIONS",
    "OBJC_COMPILE_ACTIONS",
)
load(
    "@//build/bazel/toolchains/cc:rules.bzl",
    "cc_tool",
    "cc_toolchain_import",
)
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")

package(default_visibility = ["@//build/bazel/toolchains/cc:__subpackages__"])

filegroup(
    name = "llvm_cov",
    srcs = ["bin/llvm-cov"],
    visibility = ["@//build/bazel/toolchains/rust:__subpackages__"],
)

filegroup(
    name = "llvm_profdata",
    srcs = ["bin/llvm-profdata"],
    visibility = ["@//build/bazel/toolchains/rust:__subpackages__"],
)

cc_tool(
    name = "clang",
    applied_actions = C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + ASSEMBLE_ACTIONS + LINK_ACTIONS,
    runfiles = glob(
        ["bin/*"],
        exclude = [
            "bin/clang-check",
            "bin/clangd",
            "bin/*clang-format",
            "bin/clang-tidy*",
            "bin/lldb*",
            "bin/llvm-bolt",
            "bin/llvm-config",
            "bin/llvm-cfi-verify",
        ],
    ),
    tool = ":bin/clang",
)

cc_tool(
    name = "archiver",
    applied_actions = [ACTION_NAMES.cpp_link_static_library],
    tool = ":bin/llvm-ar",
)

cc_tool(
    name = "strip",
    applied_actions = [ACTION_NAMES.strip],
    runfiles = [":bin/llvm-objcopy"],
    tool = ":bin/llvm-strip",
)

cc_toolchain_import(
    name = "libcxx",
    dynamic_mode_libs = [
        ":lib/x86_64-unknown-linux-gnu/libc++.so",
        ":lib/x86_64-unknown-linux-gnu/libc++.so.1",
    ],
    include_paths = [
        ":include/c++/v1",
        ":lib/clang/19/include",
    ],
    static_mode_libs = [
        ":lib/x86_64-unknown-linux-gnu/libc++.a",
    ],
    support_files = glob(
        [
            "include/c++/v1/**",
            "lib/clang/19/include/**",
        ],
    ),
)
