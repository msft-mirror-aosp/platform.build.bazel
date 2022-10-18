load("@//build/bazel/toolchains/cc:cc_toolchain_import.bzl", "cc_toolchain_import")

package(default_visibility = [
    "@//build/bazel/toolchains/cc:__subpackages__",
    "@clang//:__subpackages__",
])

GCC = "x86_64-linux-glibc2.17-4.8"

gcc_target = ":" + GCC

cc_toolchain_import(
    name = "start_libs",
    dynamic_mode_libs = [
        gcc_target + "/sysroot/usr/lib/crt1.o",
        gcc_target + "/sysroot/usr/lib/crti.o",
        gcc_target + "/lib/gcc/x86_64-linux/4.8.3/crtbegin.o",
        gcc_target + "/lib/gcc/x86_64-linux/4.8.3/crtend.o",
        gcc_target + "/sysroot/usr/lib/crtn.o",
    ],
    so_linked_objects = [
        gcc_target + "/sysroot/usr/lib/crti.o",
        gcc_target + "/lib/gcc/x86_64-linux/4.8.3/crtbeginS.o",
        gcc_target + "/lib/gcc/x86_64-linux/4.8.3/crtendS.o",
        gcc_target + "/sysroot/usr/lib/crtn.o",
    ],
    static_mode_libs = [
        gcc_target + "/sysroot/usr/lib/crt1.o",
        gcc_target + "/sysroot/usr/lib/crti.o",
        gcc_target + "/lib/gcc/x86_64-linux/4.8.3/crtbegin.o",
        gcc_target + "/lib/gcc/x86_64-linux/4.8.3/crtend.o",
        gcc_target + "/sysroot/usr/lib/crtn.o",
    ],
)

cc_toolchain_import(
    name = "linker",
    support_files = [
        gcc_target + "/sysroot/usr/lib/ld-linux-x86-64.so.2",
    ],
)

cc_toolchain_import(
    name = "libc",
    hdrs = glob(
        [
            GCC + "/sysroot/usr/include/*.h",
            GCC + "/sysroot/usr/include/**/*.h",
            GCC + "/sysroot/usr/include/x86_64-linux-gnu/**",
            GCC + "/lib/gcc/x86_64-linux/4.8.3/include/**",
            GCC + "/lib/gcc/x86_64-linux/4.8.3/include-fixed/**",
        ],
    ),
    dynamic_mode_libs = [
        gcc_target + "/sysroot/usr/lib/libc.so",
    ],
    include_paths = [
        gcc_target + "/sysroot/usr/include",
        gcc_target + "/sysroot/usr/include/x86_64-linux-gnu",
        gcc_target + "/lib/gcc/x86_64-linux/4.8.3/include",
        gcc_target + "/lib/gcc/x86_64-linux/4.8.3/include-fixed",
    ],
    static_mode_libs = [
        gcc_target + "/sysroot/usr/lib/libc.so",
    ],
    support_files = [
        gcc_target + "/sysroot/usr/lib/libc.so.6",
        gcc_target + "/sysroot/usr/lib/libc-2.17.so",
        gcc_target + "/sysroot/usr/lib/libc_nonshared.a",
    ],
    deps = [":linker"],
)

cc_toolchain_import(
    name = "libm",
    dynamic_mode_libs = [
        gcc_target + "/sysroot/usr/lib/libm.so",
    ],
    static_mode_libs = [
        gcc_target + "/sysroot/usr/lib/libm.so",
    ],
    support_files = [
        gcc_target + "/sysroot/usr/lib/libm.so.6",
        gcc_target + "/sysroot/usr/lib/libm-2.17.so",
    ],
    deps = [":libc"],
)

cc_toolchain_import(
    name = "libpthread",
    dynamic_mode_libs = [
        gcc_target + "/sysroot/usr/lib/libpthread.so",
    ],
    static_mode_libs = [
        gcc_target + "/sysroot/usr/lib/libpthread.so",
    ],
    support_files = [
        gcc_target + "/sysroot/usr/lib/libpthread.so.0",
        gcc_target + "/sysroot/usr/lib/libpthread-2.17.so",
        gcc_target + "/sysroot/usr/lib/libpthread_nonshared.a",
    ],
    deps = [":libc"],
)

cc_toolchain_import(
    name = "librt",
    dynamic_mode_libs = [
        gcc_target + "/sysroot/usr/lib/librt.so",
    ],
    static_mode_libs = [
        gcc_target + "/sysroot/usr/lib/librt.so",
    ],
    support_files = [
        gcc_target + "/sysroot/usr/lib/librt.so.1",
        gcc_target + "/sysroot/usr/lib/librt-2.17.so",
    ],
    deps = [
        ":libc",
        ":libpthread",
    ],
)

cc_toolchain_import(
    name = "libgcc_s",
    dynamic_mode_libs = [
        gcc_target + "/x86_64-linux/lib64/libgcc_s.so",
    ],
    static_mode_libs = [
        gcc_target + "/x86_64-linux/lib64/libgcc_s.so",
    ],
    support_files = [
        gcc_target + "/x86_64-linux/lib64/libgcc_s.so.1",
    ],
    deps = [":libc"],
)

cc_toolchain_import(
    name = "libgcc",
    dynamic_mode_libs = [
        gcc_target + "/lib/gcc/x86_64-linux/4.8.3/libgcc.a",
        gcc_target + "/lib/gcc/x86_64-linux/4.8.3/libgcc_eh.a",
    ],
    static_mode_libs = [
        gcc_target + "/lib/gcc/x86_64-linux/4.8.3/libgcc.a",
        gcc_target + "/lib/gcc/x86_64-linux/4.8.3/libgcc_eh.a",
    ],
)
