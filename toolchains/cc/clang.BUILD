load(
    "@//build/bazel/toolchains/cc:rules.bzl",
    "cc_tool",
    "cc_toolchain_import",
)
load(
    "@//build/bazel/toolchains/cc:actions.bzl",
    "ASSEMBLE_ACTIONS",
    "CPP_COMPILE_ACTIONS",
    "C_COMPILE_ACTIONS",
    "LINK_ACTIONS",
)
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")

package(default_visibility = ["@//build/bazel/toolchains/cc:__subpackages__"])

# The clang path definition for each platform
CLANG_LINUX_X64 = "linux-x86/clang-r487747"

target_linux_x64 = ":" + CLANG_LINUX_X64

cc_tool(
    name = "linux_x64_clang",
    applied_actions = C_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + ASSEMBLE_ACTIONS + LINK_ACTIONS,
    runfiles = glob(
        [CLANG_LINUX_X64 + "/bin/*"],
        allow_empty = False,
        exclude = [
            CLANG_LINUX_X64 + "/bin/clang-check",
            CLANG_LINUX_X64 + "/bin/clangd",
            CLANG_LINUX_X64 + "/bin/*clang-format",
            CLANG_LINUX_X64 + "/bin/clang-tidy*",
            CLANG_LINUX_X64 + "/bin/lldb*",
            CLANG_LINUX_X64 + "/bin/llvm-bolt",
            CLANG_LINUX_X64 + "/bin/llvm-config",
            CLANG_LINUX_X64 + "/bin/llvm-cfi-verify",
        ],
    ),
    tool = target_linux_x64 + "/bin/clang",
)

cc_tool(
    name = "linux_x64_archiver",
    applied_actions = [ACTION_NAMES.cpp_link_static_library],
    tool = target_linux_x64 + "/bin/llvm-ar",
)

cc_tool(
    name = "linux_x64_strip",
    applied_actions = [ACTION_NAMES.strip],
    runfiles = [target_linux_x64 + "/bin/llvm-objcopy"],
    tool = target_linux_x64 + "/bin/llvm-strip",
)

cc_toolchain_import(
    name = "linux_x64_libcxx",
    hdrs = glob(
        [
            CLANG_LINUX_X64 + "/include/c++/v1/**",
            CLANG_LINUX_X64 + "/lib/clang/17/include/**",
        ],
        allow_empty = False,
    ),
    dynamic_mode_libs = [
        target_linux_x64 + "/lib/x86_64-unknown-linux-gnu/libc++.so",
        target_linux_x64 + "/lib/x86_64-unknown-linux-gnu/libc++.so.1",
    ],
    include_paths = [
        target_linux_x64 + "/include/c++/v1",
        target_linux_x64 + "/lib/clang/17/include",
    ],
    is_runtime_lib = True,
    static_mode_libs = [
        target_linux_x64 + "/lib/x86_64-unknown-linux-gnu/libc++.a",
    ],
    deps = [
        "@gcc_lib//:libc",
        "@gcc_lib//:libgcc",
        "@gcc_lib//:libgcc_s",
        "@gcc_lib//:libm",
        "@gcc_lib//:libpthread",
        "@gcc_lib//:librt",
    ],
)