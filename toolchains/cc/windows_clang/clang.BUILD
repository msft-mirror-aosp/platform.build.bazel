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
    srcs = ["bin/llvm-cov.exe"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "llvm_profdata",
    srcs = ["bin/llvm-profdata.exe"],
    visibility = ["//visibility:public"],
)

cc_tool(
    name = "clang-cl",
    applied_actions = C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + ASSEMBLE_ACTIONS,
    runfiles = glob(
        ["bin/*"],
        exclude = [
            "bin/clang-check.exe",
            "bin/clang-format.exe",
            "bin/git-clang-format",
            "bin/clang-tidy.exe",
            "bin/lldb*",
            "bin/llvm-config.exe",
            "bin/llvm-cfi-verify.exe",
        ],
    ),
    tool = ":bin/clang-cl.exe",
)

cc_tool(
    name = "link",
    applied_actions = LINK_ACTIONS,
    runfiles = glob(
        ["bin/*"],
        exclude = [
            "bin/clang-check.exe",
            "bin/clang-format.exe",
            "bin/git-clang-format",
            "bin/clang-tidy.exe",
            "bin/lldb*",
            "bin/llvm-config.exe",
            "bin/llvm-cfi-verify.exe",
        ],
    ),
    tool = ":bin/lld-link.exe",
)

cc_tool(
    name = "archiver",
    applied_actions = [ACTION_NAMES.cpp_link_static_library],
    runfiles = [":bin/llvm-ar.exe"],
    tool = ":bin/llvm-lib.exe",
)

cc_toolchain_import(
    name = "compiler_runtime",
    include_paths = [
        ":lib/clang/19/include",
    ],
    support_files = glob(["lib/clang/19/include/**"]),
)
