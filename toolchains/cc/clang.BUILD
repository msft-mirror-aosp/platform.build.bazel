load("@//build/bazel/toolchains/cc:cc_toolchain_config.bzl", "cc_tools")

package(default_visibility = ["@//build/bazel/toolchains/cc:__subpackages__"])

# The clang path definition for each platform
CLANG_LINUX_X64 = "linux-x86/clang-r450784d"

target_linux_x64 = ":" + CLANG_LINUX_X64

cc_tools(
    name = "linux_x64",
    ar = target_linux_x64 + "/bin/llvm-ar",
    ar_features = [
        "archiver_flags",
    ],
    cxx = target_linux_x64 + "/bin/clang++",
    gcc = target_linux_x64 + "/bin/clang",
    ld = target_linux_x64 + "/bin/clang++",
    ld_features = [
        "shared_flag",
        "linkstamps",
        "output_execpath_flags",
        "runtime_library_search_directories",
        "library_search_directories",
        "libraries_to_link",
        "force_pic_flags",
        "user_link_flags",
        "strip_debug_symbols",
        "linker_param_file",
    ],
    strip = target_linux_x64 + "/bin/llvm-strip",
)

filegroup(
    name = "linux_x64_binaries",
    srcs = glob(
        [CLANG_LINUX_X64 + "/bin/*"],
        allow_empty = False,
    ),
)

filegroup(
    name = "linux_x64_includes",
    srcs = glob(
        [
            CLANG_LINUX_X64 + "/lib64/clang/*/include/**",
            CLANG_LINUX_X64 + "/include/c++/v1/**",
        ],
        allow_empty = False,
    ),
)

filegroup(
    name = "linux_x64_libs",
    srcs = glob(
        [
            CLANG_LINUX_X64 + "/lib64/*",
            CLANG_LINUX_X64 + "/lib64/clang/*/lib/linux/**",
        ],
        allow_empty = False,
    ),
)

filegroup(
    name = "linux_x64_include_paths",
    srcs = glob(
        [CLANG_LINUX_X64 + "/lib64/clang/*/include"],
        allow_empty = False,
        exclude_directories = 0,
    ) + [CLANG_LINUX_X64 + "/include/c++/v1"],
)

filegroup(
    name = "linux_x64_lib_paths",
    srcs = glob(
        [CLANG_LINUX_X64 + "/lib64/clang/*/lib/linux"],
        allow_empty = False,
        exclude_directories = 0,
    ) + [target_linux_x64 + "/lib64"],
)

cc_library(
    name = "linux_x64_runtime_libs",
    srcs = glob(
        [
            CLANG_LINUX_X64 + "/lib64/*.so",
            CLANG_LINUX_X64 + "/lib64/*.so.*",
        ],
    ),
    visibility = ["//visibility:public"],
)
