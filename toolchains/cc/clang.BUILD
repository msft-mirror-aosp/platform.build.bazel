load(
    "@//build/bazel/toolchains/cc:actions.bzl",
    "ARCHIVER_ACTIONS",
    "ASSEMBLE_ACTIONS",
    "CPP_COMPILE_ACTIONS",
    "C_COMPILE_ACTIONS",
    "LINK_ACTIONS",
)
load(
    "@//build/bazel/toolchains/cc:rules.bzl",
    "cc_tool",
    "cc_toolchain_import",
)
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@toolchain_defs//:defs.bzl", "TOOL_VERSIONS")

package(default_visibility = ["@//build/bazel/toolchains/cc:__subpackages__"])

# The clang path definition for each platform
CLANG_LINUX_X64 = "linux-x86/{}".format(TOOL_VERSIONS["clang"])

CLANG_MACOS_ALL = "darwin-x86/{}".format(TOOL_VERSIONS["clang"])

CLANG_WIN_X64 = "windows-x86/{}".format(TOOL_VERSIONS["clang"])

target_linux_x64 = ":" + CLANG_LINUX_X64

target_macos_all = ":" + CLANG_MACOS_ALL

target_win_x64 = ":" + CLANG_WIN_X64

###################### Linux X64 ######################

cc_tool(
    name = "linux_x64_clang",
    applied_actions = C_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + ASSEMBLE_ACTIONS + LINK_ACTIONS,
    runfiles = glob(
        [CLANG_LINUX_X64 + "/bin/*"],
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
    dynamic_mode_libs = [
        target_linux_x64 + "/lib/x86_64-unknown-linux-gnu/libc++.so",
        target_linux_x64 + "/lib/x86_64-unknown-linux-gnu/libc++.so.1",
    ],
    include_paths = [
        target_linux_x64 + "/include/c++/v1",
        target_linux_x64 + "/lib/clang/17/include",
    ],
    static_mode_libs = [
        target_linux_x64 + "/lib/x86_64-unknown-linux-gnu/libc++.a",
    ],
    support_files = glob(
        [
            CLANG_LINUX_X64 + "/include/c++/v1/**",
            CLANG_LINUX_X64 + "/lib/clang/17/include/**",
        ],
    ),
    system_provided = False,
    deps = [
        "@gcc_lib//:libc",
        "@gcc_lib//:libgcc",
        "@gcc_lib//:libgcc_s",
        "@gcc_lib//:libm",
        "@gcc_lib//:libpthread",
        "@gcc_lib//:librt",
    ],
)

###################### macOS ######################

cc_tool(
    name = "macos_all_clang",
    applied_actions = C_COMPILE_ACTIONS + ASSEMBLE_ACTIONS,
    runfiles = glob(
        [CLANG_MACOS_ALL + "/bin/*"],
        exclude = [
            CLANG_MACOS_ALL + "/bin/clang-check",
            CLANG_MACOS_ALL + "/bin/clangd",
            CLANG_MACOS_ALL + "/bin/*clang-format",
            CLANG_MACOS_ALL + "/bin/clang-tidy*",
            CLANG_MACOS_ALL + "/bin/lldb*",
            CLANG_MACOS_ALL + "/bin/llvm-bolt",
            CLANG_MACOS_ALL + "/bin/llvm-config",
            CLANG_MACOS_ALL + "/bin/llvm-cfi-verify",
        ],
    ),
    tool = target_macos_all + "/bin/clang",
)

cc_tool(
    name = "macos_all_clang++",
    applied_actions = CPP_COMPILE_ACTIONS + LINK_ACTIONS,
    runfiles = glob(
        [CLANG_MACOS_ALL + "/bin/*"],
        exclude = [
            CLANG_MACOS_ALL + "/bin/clang-check",
            CLANG_MACOS_ALL + "/bin/clangd",
            CLANG_MACOS_ALL + "/bin/*clang-format",
            CLANG_MACOS_ALL + "/bin/clang-tidy*",
            CLANG_MACOS_ALL + "/bin/lldb*",
            CLANG_MACOS_ALL + "/bin/llvm-bolt",
            CLANG_MACOS_ALL + "/bin/llvm-config",
            CLANG_MACOS_ALL + "/bin/llvm-cfi-verify",
        ],
    ),
    tool = target_macos_all + "/bin/clang++",
)

cc_tool(
    name = "macos_all_archiver",
    applied_actions = ARCHIVER_ACTIONS,
    tool = target_macos_all + "/bin/llvm-ar",
)

cc_tool(
    name = "macos_all_strip",
    applied_actions = [ACTION_NAMES.strip],
    runfiles = [target_macos_all + "/bin/llvm-objcopy"],
    tool = target_macos_all + "/bin/llvm-strip",
)

cc_toolchain_import(
    name = "macos_all_libcxx",
    dynamic_mode_libs = [
        target_macos_all + "/lib/libc++.dylib",
        target_macos_all + "/lib/libc++.1.dylib",
        target_macos_all + "/lib/libc++abi.1.dylib",
    ],
    include_paths = [
        target_macos_all + "/include/c++/v1",
        target_macos_all + "/lib/clang/17/include",
    ],
    static_mode_libs = [
        target_macos_all + "/lib/libc++.a",
        target_macos_all + "/lib/libc++abi.a",
    ],
    support_files = glob(
        [
            CLANG_MACOS_ALL + "/include/c++/v1/**",
            CLANG_MACOS_ALL + "/lib/clang/17/include/**",
        ],
    ),
    system_provided = False,
)

###################### Windows X64 ######################

cc_tool(
    name = "win_x64_clang-cl",
    applied_actions = C_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + ASSEMBLE_ACTIONS,
    runfiles = glob(
        [CLANG_WIN_X64 + "/bin/*"],
        exclude = [
            CLANG_WIN_X64 + "/bin/clang-check.exe",
            CLANG_WIN_X64 + "/bin/clang-format.exe",
            CLANG_WIN_X64 + "/bin/git-clang-format",
            CLANG_WIN_X64 + "/bin/clang-tidy.exe",
            CLANG_WIN_X64 + "/bin/lldb*",
            CLANG_WIN_X64 + "/bin/llvm-config.exe",
            CLANG_WIN_X64 + "/bin/llvm-cfi-verify.exe",
        ],
    ),
    tool = target_win_x64 + "/bin/clang-cl.exe",
)

cc_tool(
    name = "win_x64_link",
    applied_actions = LINK_ACTIONS,
    runfiles = glob(
        [CLANG_WIN_X64 + "/bin/*"],
        exclude = [
            CLANG_WIN_X64 + "/bin/clang-check.exe",
            CLANG_WIN_X64 + "/bin/clang-format.exe",
            CLANG_WIN_X64 + "/bin/git-clang-format",
            CLANG_WIN_X64 + "/bin/clang-tidy.exe",
            CLANG_WIN_X64 + "/bin/lldb*",
            CLANG_WIN_X64 + "/bin/llvm-config.exe",
            CLANG_WIN_X64 + "/bin/llvm-cfi-verify.exe",
        ],
    ),
    tool = target_win_x64 + "/bin/lld-link.exe",
)

cc_tool(
    name = "win_x64_archiver",
    applied_actions = [ACTION_NAMES.cpp_link_static_library],
    runfiles = [target_win_x64 + "/bin/llvm-ar.exe"],
    tool = target_win_x64 + "/bin/llvm-lib.exe",
)

cc_toolchain_import(
    name = "win_x64_compiler_runtime",
    include_paths = [
        target_win_x64 + "/lib/clang/17/include",
    ],
    support_files = glob([CLANG_WIN_X64 + "/lib/clang/17/include/**"]),
)
