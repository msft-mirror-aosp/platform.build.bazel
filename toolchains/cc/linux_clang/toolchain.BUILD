load(
    "@goldfish_build//toolchains/cc:rules.bzl",
    "cc_toolchain_config",
    "cc_toolchain_dynamic_runtime",
    "cc_toolchain_static_runtime",
)
load("@goldfish_build//toolchains/cc/linux_clang:features.bzl", "cc_features")
load("@rules_cc//cc:defs.bzl", "cc_toolchain")

package(default_visibility = ["//visibility:public"])

_x64_imports = [
    "@clang_linux_x64//:libcxx",
    "@clang_linux_x64//:compiler_rt",
    "@clang_linux_x64//:libunwind",
    "@gcc_lib//:start_libs",
    "@gcc_lib//:libs",
]

cc_features(
    name = "x64_features",
    assembler_flags = [
        "--target=x86_64-unknown-linux-gnu",
    ],
    b_prefix = "@gcc_lib//:lib/gcc/x86_64-linux/4.8.3",
    compile_flags = [
        "--target=x86_64-unknown-linux-gnu",
        "-fstack-protector-strong",
        "-fcolor-diagnostics",
    ],
    cxx_flags = [
        "-std=c++26",
        "-fno-exceptions",
    ],
    link_flags = [
        "--target=x86_64-unknown-linux-gnu",
        "-fuse-ld=lld",
        "-rtlib=compiler-rt",
        "-Wno-unused-command-line-argument",
        "-Wl,--as-needed",
        "-lm",
        "-ldl",
        "-Wl,--no-as-needed",
        "-l:libunwind.a",
    ],
    toolchain_imports = _x64_imports,
)

cc_toolchain_config(
    name = "x64_config",
    cc_features = ":x64_features",
    cc_tools = [
        "@clang_linux_x64//:clang",
        "@clang_linux_x64//:clang-tidy",
        "@clang_linux_x64//:archiver",
        "@clang_linux_x64//:strip",
    ],
    compiler_name = "clang",
    identifier = "linux_clang_x64",
    sysroot = "@gcc_lib//:sysroot",
    target_cpu = "k8",
    toolchain_imports = _x64_imports,
)

cc_toolchain_dynamic_runtime(
    name = "x64_dynamic_runtime",
    libs = _x64_imports,
)

cc_toolchain_static_runtime(
    name = "x64_static_runtime",
    libs = _x64_imports,
)

cc_toolchain(
    name = "x64",
    all_files = ":x64_config",
    ar_files = "@clang_linux_x64//:archiver",
    as_files = "@clang_linux_x64//:clang",
    compiler_files = ":x64_config",
    dwp_files = "@goldfish_build//toolchains/cc:empty",
    dynamic_runtime_lib = ":x64_dynamic_runtime",
    linker_files = ":x64_config",
    objcopy_files = "@goldfish_build//toolchains/cc:empty",
    static_runtime_lib = ":x64_static_runtime",
    strip_files = "@clang_linux_x64//:strip",
    supports_param_files = True,
    toolchain_config = ":x64_config",
)

toolchain(
    name = "x64_toolchain",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
        "@bazel_tools//tools/cpp:clang",
    ],
    target_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ],
    toolchain = ":x64",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

toolchain(
    name = "x64_objcopy_toolchain",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ],
    toolchain = "@clang_linux_x64//:objcopy",
    toolchain_type = "@goldfish_build//toolchains/cc:objcopy_toolchain_type",
)
