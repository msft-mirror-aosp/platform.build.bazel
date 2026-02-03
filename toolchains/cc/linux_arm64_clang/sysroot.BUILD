load("@goldfish_build//toolchains/cc:rules.bzl", "cc_toolchain_import", "sysroot")

package(default_visibility = ["//visibility:public"])

cc_toolchain_import(
    name = "linker",
    lib_search_paths = [
        "lib/gcc/aarch64-none-linux-gnu/13.2.1",
    ],
    support_files = [
        "aarch64-none-linux-gnu/libc/lib/ld-linux-aarch64.so.1",
    ] + glob([
        "lib/gcc/aarch64-none-linux-gnu/13.2.1/**/*.a",
        "lib/gcc/aarch64-none-linux-gnu/13.2.1/**/*.o",
    ]),
)

cc_toolchain_import(
    name = "libstdcxx",
    dynamic_mode_libs = [
        "aarch64-none-linux-gnu/lib64/libstdc++.so",
        "aarch64-none-linux-gnu/lib64/libgcc_s.so",
    ],
    include_paths = [
        "aarch64-none-linux-gnu/include/c++/13.2.1",
        "aarch64-none-linux-gnu/include/c++/13.2.1/aarch64-none-linux-gnu",
        "aarch64-none-linux-gnu/include/c++/13.2.1/backward",
    ],
    static_mode_libs = [
        "aarch64-none-linux-gnu/lib64/libstdc++.a",
        "lib/gcc/aarch64-none-linux-gnu/13.2.1/libgcc.a",
        "lib/gcc/aarch64-none-linux-gnu/13.2.1/libgcc_eh.a",
    ],
    support_files = glob([
        "aarch64-none-linux-gnu/include/c++/**",
    ]),
)

cc_toolchain_import(
    name = "libs",
    include_paths = [
        "aarch64-none-linux-gnu/include",
        "aarch64-none-linux-gnu/libc/usr/include",
    ],
    lib_search_paths = [
        "aarch64-none-linux-gnu/libc/lib64",
        "aarch64-none-linux-gnu/libc/usr/lib64",
        "aarch64-none-linux-gnu/libc/usr/lib",
        "lib/gcc/aarch64-none-linux-gnu/13.2.1",
    ],
    deps = [":linker"],
)

sysroot(
    name = "arm_sysroot",
    all_files = glob(["aarch64-none-linux-gnu/libc/**"]),
    path = "aarch64-none-linux-gnu/libc",
)
