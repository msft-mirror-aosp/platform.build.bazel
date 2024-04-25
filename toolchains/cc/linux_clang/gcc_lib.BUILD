load("@//build/bazel/toolchains/cc:rules.bzl", "cc_toolchain_import")

package(default_visibility = [
    "@//build/bazel/toolchains/cc:__subpackages__",
    "@clang//:__subpackages__",
])

cc_toolchain_import(
    name = "start_libs",
    dynamic_mode_libs = [
        ":sysroot/usr/lib/Scrt1.o",
        ":sysroot/usr/lib/crti.o",
        ":lib/gcc/x86_64-linux/4.8.3/crtbeginS.o",
        ":lib/gcc/x86_64-linux/4.8.3/crtendS.o",
        ":sysroot/usr/lib/crtn.o",
    ],
    so_linked_objects = [
        ":sysroot/usr/lib/crti.o",
        ":lib/gcc/x86_64-linux/4.8.3/crtbeginS.o",
        ":lib/gcc/x86_64-linux/4.8.3/crtendS.o",
        ":sysroot/usr/lib/crtn.o",
    ],
    static_mode_libs = [
        ":sysroot/usr/lib/Scrt1.o",
        ":sysroot/usr/lib/crti.o",
        ":lib/gcc/x86_64-linux/4.8.3/crtbeginS.o",
        ":lib/gcc/x86_64-linux/4.8.3/crtendS.o",
        ":sysroot/usr/lib/crtn.o",
    ],
)

cc_toolchain_import(
    name = "linker",
    support_files = [
        ":sysroot/usr/lib/ld-linux-x86-64.so.2",
    ],
)

cc_toolchain_import(
    name = "libc",
    dynamic_mode_libs = [
        ":sysroot/usr/lib/libc.so",
    ],
    include_paths = [
        ":sysroot/usr/include",
        ":sysroot/usr/include/x86_64-linux-gnu",
        ":lib/gcc/x86_64-linux/4.8.3/include",
        ":lib/gcc/x86_64-linux/4.8.3/include-fixed",
    ],
    static_mode_libs = [
        ":sysroot/usr/lib/libc.so",
    ],
    support_files = glob([
        "sysroot/usr/include/*.h",
        "sysroot/usr/include/**/*.h",
        "sysroot/usr/include/x86_64-linux-gnu/**",
        "lib/gcc/x86_64-linux/4.8.3/include/**",
        "lib/gcc/x86_64-linux/4.8.3/include-fixed/**",
    ]) + [
        ":sysroot/usr/lib/libc.so.6",
        ":sysroot/usr/lib/libc-2.17.so",
        ":sysroot/usr/lib/libc_nonshared.a",
    ],
    deps = [":linker"],
)

cc_toolchain_import(
    name = "libm",
    dynamic_mode_libs = [
        ":sysroot/usr/lib/libm.so",
    ],
    static_mode_libs = [
        ":sysroot/usr/lib/libm.so",
    ],
    support_files = [
        ":sysroot/usr/lib/libm.so.6",
        ":sysroot/usr/lib/libm-2.17.so",
    ],
    deps = [":libc"],
)

cc_toolchain_import(
    name = "libdl",
    dynamic_mode_libs = [
        ":sysroot/usr/lib/libdl.so",
    ],
    static_mode_libs = [
        ":sysroot/usr/lib/libdl.so",
    ],
    support_files = [
        ":sysroot/usr/lib/libdl.so.2",
        ":sysroot/usr/lib/libdl-2.17.so",
    ],
    deps = [":libc"],
)

cc_toolchain_import(
    name = "libpthread",
    dynamic_mode_libs = [
        ":sysroot/usr/lib/libpthread.so",
    ],
    static_mode_libs = [
        ":sysroot/usr/lib/libpthread.so",
    ],
    support_files = [
        ":sysroot/usr/lib/libpthread.so.0",
        ":sysroot/usr/lib/libpthread-2.17.so",
        ":sysroot/usr/lib/libpthread_nonshared.a",
    ],
    deps = [":libc"],
)

cc_toolchain_import(
    name = "librt",
    dynamic_mode_libs = [
        ":sysroot/usr/lib/librt.so",
    ],
    static_mode_libs = [
        ":sysroot/usr/lib/librt.so",
    ],
    support_files = [
        ":sysroot/usr/lib/librt.so.1",
        ":sysroot/usr/lib/librt-2.17.so",
    ],
    deps = [
        ":libc",
        ":libpthread",
    ],
)

cc_import(
    name = "libpulse",
    interface_library = ":sysroot/usr/lib/libpulse.so",
    shared_library = ":sysroot/usr/lib/libpulse.so.0.15.3",
    visibility = ["//visibility:public"],
)

cc_import(
    name = "libutil",
    static_library = ":sysroot/usr/lib/libutil.a",
    visibility = ["//visibility:public"],
)

cc_toolchain_import(
    name = "libgcc_s",
    dynamic_mode_libs = [
        ":x86_64-linux/lib64/libgcc_s.so",
    ],
    static_mode_libs = [
        ":x86_64-linux/lib64/libgcc_s.so",
    ],
    support_files = [
        ":x86_64-linux/lib64/libgcc_s.so.1",
    ],
    deps = [":libc"],
)

cc_toolchain_import(
    name = "libgcc",
    dynamic_mode_libs = [
        ":lib/gcc/x86_64-linux/4.8.3/libgcc.a",
        ":lib/gcc/x86_64-linux/4.8.3/libgcc_eh.a",
    ],
    static_mode_libs = [
        ":lib/gcc/x86_64-linux/4.8.3/libgcc.a",
        ":lib/gcc/x86_64-linux/4.8.3/libgcc_eh.a",
    ],
)
