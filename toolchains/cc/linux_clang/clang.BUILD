load(
    "@//build/bazel/toolchains/cc:actions.bzl",
    "ASSEMBLE_ACTIONS",
    "CPP_COMPILE_ACTIONS",
    "C_COMPILE_ACTIONS",
    "LINK_ACTIONS",
    "LTO_BACKEND_ACTIONS",
    "LTO_INDEX_ACTIONS",
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
        ":lib/x86_64-unknown-linux-gnu/libc++abi.so",
    ],
    include_paths = [
        ":include/c++/v1",
    ],
    static_mode_libs = [
        ":lib/x86_64-unknown-linux-gnu/libc++.a",
        ":lib/x86_64-unknown-linux-gnu/libc++abi.a",
    ],
    support_files = glob(
        [
            "include/c++/v1/**",
        ],
    ),
)

cc_toolchain_import(
    name = "compiler_rt",
    include_paths = glob(
        [
            "lib/clang/*/include",
        ],
        exclude_directories = 0,
    ),
    lib_search_paths = glob(
        [
            "lib/clang/*/lib/x86_64-unknown-linux-gnu",
        ],
        exclude_directories = 0,
    ),
    support_files = glob(
        [
            "lib/clang/*/include/**",
            "lib/clang/*/share/**",
            "lib/clang/*/lib/x86_64-unknown-linux-gnu/*",
        ],
    ),
)

cc_toolchain_import(
    name = "libunwind",
    lib_search_paths = [
        ":lib/x86_64-unknown-linux-gnu",
    ],
    support_files = [
        ":lib/x86_64-unknown-linux-gnu/libunwind.a",
    ],
)
