load("@bazel_skylib//rules:copy_file.bzl", "copy_file")
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
            "lib/libxml2.so*",
        ],
        exclude = [
            "bin/clang++*",
            "bin/clang-check",
            "bin/clang-scan-deps",
            "bin/clangd",
            "bin/*clang-format",
            "bin/clang-tidy*",
        ],
    ),
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

cc_tool(
    name = "clang-tidy",
    applied_actions = ["clang-tidy"],
    runfiles = glob(["bin/clang-tidy*"]),
    tool = ":bin/clang-tidy",
)

cc_toolchain_import(
    name = "libcxx",
    dynamic_mode_libs = [
        ":lib/x86_64-unknown-linux-gnu/libc++.so",
        ":lib/x86_64-unknown-linux-gnu/libc++abi.so",
    ],
    include_paths = [":include/c++/v1"],
    static_mode_libs = [
        ":lib/x86_64-unknown-linux-gnu/libc++.a",
        ":lib/x86_64-unknown-linux-gnu/libc++abi.a",
    ],
    support_files = glob(["include/c++/v1/**"]),
)

cc_toolchain_import(
    name = "compiler_hdrs",
    include_paths = glob(
        ["lib/clang/*/include"],
        exclude_directories = 0,
    ),
    support_files = glob([
        "lib/clang/*/include/**",
        "lib/clang/*/share/**",
    ]),
)

cc_toolchain_import(
    name = "compiler_rt",
    lib_search_paths = glob(
        ["lib/clang/*/lib/x86_64-unknown-linux-gnu"],
        exclude_directories = 0,
    ),
    support_files = glob(["lib/clang/*/lib/x86_64-unknown-linux-gnu/*"]),
    deps = [":compiler_hdrs"],
)

copy_file(
    name = "libunwind_as_libgcc",
    src = ":lib/x86_64-unknown-linux-gnu/libunwind.a",
    out = "lib_patch/x86_64-unknown-linux-gnu/libgcc_s.a",
    visibility = ["//visibility:private"],
)

cc_toolchain_import(
    name = "libunwind",
    libs = [
        ":lib/x86_64-unknown-linux-gnu/libunwind.a",
        ":libunwind_as_libgcc",
    ],
)

simple_toolchain(
    name = "objcopy",
    executable = ":bin/llvm-objcopy",
)
