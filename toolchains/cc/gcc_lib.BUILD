package(default_visibility = ["@//build/bazel/toolchains/cc:__subpackages__"])

GCC = "x86_64-linux-glibc2.17-4.8"

gcc_target = ":" + GCC

filegroup(
    name = "includes",
    srcs = glob(
        [GCC + "/sysroot/usr/include/**"],
        allow_empty = False,
    ),
)

filegroup(
    name = "libs",
    srcs = glob(
        [
            GCC + "/sysroot/usr/lib*/**",
            GCC + "/lib/gcc/x86_64-linux/4.8.3/**",
            GCC + "/x86_64-linux/lib64/*",
        ],
        allow_empty = False,
    ),
)

alias(
    name = "sysroot_path",
    actual = gcc_target + "/sysroot",
)

alias(
    name = "toolchain_path",
    actual = gcc_target,
)

filegroup(
    name = "include_paths",
    srcs = [
        gcc_target + "/sysroot/usr/include",
        gcc_target + "/sysroot/usr/include/x86_64-linux-gnu",
    ],
)

filegroup(
    name = "lib_paths",
    srcs = [
        gcc_target + "/lib/gcc/x86_64-linux/4.8.3",
        gcc_target + "/x86_64-linux/lib64",
    ],
)

filegroup(
    name = "binary_search_path",
    srcs = [gcc_target + "/lib/gcc/x86_64-linux/4.8.3"],
)
