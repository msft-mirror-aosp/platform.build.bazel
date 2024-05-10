load("@//build/bazel/toolchains/cc:rules.bzl", "cc_toolchain_import", "sysroot")

package(default_visibility = [
    "@//build/bazel/toolchains/cc:__subpackages__",
    "@clang//:__subpackages__",
])

cc_toolchain_import(
    name = "start_libs",
    support_files = [
        ":lib/gcc/x86_64-linux/4.8.3/crtbeginS.o",
        ":lib/gcc/x86_64-linux/4.8.3/crtendS.o",
        ":sysroot/usr/lib/Scrt1.o",
        ":sysroot/usr/lib/crti.o",
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
    name = "libs",
    include_paths = [
        ":sysroot/usr/include",
        ":sysroot/usr/include/x86_64-linux-gnu",
        ":lib/gcc/x86_64-linux/4.8.3/include",
        ":lib/gcc/x86_64-linux/4.8.3/include-fixed",
    ],
    lib_search_paths = [
        ":lib/gcc/x86_64-linux/4.8.3",
        ":x86_64-linux/lib64",
    ],
    support_files = glob([
        "sysroot/usr/include/*.h",
        "sysroot/usr/include/**/*.h",
        "sysroot/usr/include/x86_64-linux-gnu/**",
        "lib/gcc/x86_64-linux/4.8.3/include/**",
        "lib/gcc/x86_64-linux/4.8.3/include-fixed/**",
    ]) + [
        # keep sorted
        ":lib/gcc/x86_64-linux/4.8.3/libgcc.a",
        ":lib/gcc/x86_64-linux/4.8.3/libgcc_eh.a",
        ":sysroot/usr/lib/libc.so",
        ":sysroot/usr/lib/libc.so.6",
        ":sysroot/usr/lib/libc-2.17.so",
        ":sysroot/usr/lib/libc_nonshared.a",
        ":sysroot/usr/lib/libdl.so",
        ":sysroot/usr/lib/libdl.so.2",
        ":sysroot/usr/lib/libdl-2.17.so",
        ":sysroot/usr/lib/libm.so",
        ":sysroot/usr/lib/libm.so.6",
        ":sysroot/usr/lib/libm-2.17.so",
        ":sysroot/usr/lib/libpthread.so",
        ":sysroot/usr/lib/libpthread.so.0",
        ":sysroot/usr/lib/libpthread-2.17.so",
        ":sysroot/usr/lib/libpthread_nonshared.a",
        ":sysroot/usr/lib/librt.so",
        ":sysroot/usr/lib/librt.so.1",
        ":sysroot/usr/lib/librt-2.17.so",
        ":sysroot/usr/lib/libutil.so",
        ":sysroot/usr/lib/libutil-2.17.so",
        ":x86_64-linux/lib64/libgcc_s.so",
        ":x86_64-linux/lib64/libgcc_s.so.1",
    ],
    deps = [":linker"],
)

cc_import(
    name = "libpulse",
    interface_library = ":sysroot/usr/lib/libpulse.so",
    shared_library = ":sysroot/usr/lib/libpulse.so.0.15.3",
    visibility = ["//visibility:public"],
)

cc_import(
    name = "libutil",
    interface_library = ":sysroot/usr/lib/libutil.so",
    shared_library = ":sysroot/usr/lib/libutil-2.17.so",
    visibility = ["//visibility:public"],
)

sysroot(
    name = "sysroot",
    path = "sysroot",
)

exports_files(
    srcs = ["lib/gcc/x86_64-linux/4.8.3"],
)
