load(
    "@goldfish_build//toolchains/cc:rules.bzl",
    "cc_artifact_name",
    "cc_toolchain_config",
    "cc_toolchain_dynamic_runtime",
    "cc_toolchain_static_runtime",
)
load("@goldfish_build//toolchains/cc/mac_clang:features.bzl", "cc_features")
load("@rules_cc//cc:defs.bzl", "cc_toolchain")

package(default_visibility = ["//visibility:public"])

config_setting(
    name = "is_hermetic_xcode",
    flag_values = {
        "@goldfish_build//toolchains/cc/mac_clang:hermetic_xcode": "true",
    },
)

alias(
    name = "xcode_sdk",
    actual = select({
        ":is_hermetic_xcode": "@xcode_tools_hermetic//:sdk",
        "//conditions:default": "@xcode_tools//:sdk",
    }),
)

alias(
    name = "xcode_libcxx",
    actual = select({
        ":is_hermetic_xcode": "@xcode_tools_hermetic//:libcxx",
        "//conditions:default": "@xcode_tools//:libcxx",
    }),
)

alias(
    name = "xcode_frameworks",
    actual = select({
        ":is_hermetic_xcode": "@xcode_tools_hermetic//:frameworks",
        "//conditions:default": "@xcode_tools//:frameworks",
    }),
)

alias(
    name = "xcode_mig",
    actual = select({
        ":is_hermetic_xcode": "@xcode_tools_hermetic//:mig",
        "//conditions:default": "@xcode_tools//:mig",
    }),
    visibility = ["//visibility:public"],
)

toolchain(
    name = "mig_toolchain",
    exec_compatible_with = [
        "@platforms//os:macos",
        "@bazel_tools//tools/cpp:clang",
    ],
    target_compatible_with = [
        "@platforms//os:macos",
    ],
    toolchain = ":xcode_mig",
    toolchain_type = "@goldfish_build//toolchains/cc/mac_clang:mig_toolchain_type",
)

_imports = [
    ":xcode_libcxx",
    "@clang_mac_all//:compiler_rt",
    ":xcode_frameworks",
]

cc_features(
    name = "x64_features",
    assembler_flags = [
        "--target=x86_64-apple-darwin-macho",
        "-mmacos-version-min=10.15",
    ],
    cc_only_link_flags = [
        "-undefined error",  # This is the default.
        "-fobjc-link-runtime",
        "-lc++",
        "-lc++abi",
    ],
    compile_flags = [
        "--target=x86_64-apple-darwin-macho",
        "-mmacos-version-min=10.15",
        "-Wall",
        "-Wthread-safety",
        "-Werror=unguarded-availability-new",  # API not available in the targetd OS version.
        "-fstack-protector-strong",
        "-fcolor-diagnostics",
    ] + select({
        "@goldfish_build//toolchains/cc:is_bootstrap": [],
        "//conditions:default": ["-fdebug-prefix-map={BAZEL_EXECUTION_ROOT}=."],
    }),
    cxx_flags = [
        "-std=c++20",
        "-fno-exceptions",
    ],
    link_flags = [
        "--target=x86_64-apple-darwin-macho",
        "-mmacos-version-min=10.15",
        "-fuse-ld=lld",
        "-rtlib=compiler-rt",
    ] + select({
        "@goldfish_build//toolchains/cc:is_bootstrap": [],
        "//conditions:default": ["-Wl,-oso_prefix,{BAZEL_EXECUTION_ROOT}/"],
    }),
    toolchain_imports = _imports,
)

cc_artifact_name(
    name = "dylib",
    category = "dynamic_library",
    extension = ".dylib",
    prefix = "lib",
)

cc_toolchain_config(
    name = "x64_config",
    artifact_name_patterns = [":dylib"],
    cc_features = ":x64_features",
    cc_tools = [
        "@clang_mac_all//:clang",
        "@clang_mac_all//:clang++",
        "@clang_mac_all//:clang-tidy",
        "@clang_mac_all//:archiver",
        "@clang_mac_all//:strip",
        "@clang_mac_all//:dsymutil",
    ],
    compiler_name = "clang",
    identifier = "macos_clang_x64",
    sysroot = ":xcode_sdk",
    target_cpu = "k8",
    toolchain_imports = _imports,
)

cc_toolchain_dynamic_runtime(
    name = "dynamic_runtime",
    libs = _imports,
)

cc_toolchain_static_runtime(
    name = "static_runtime",
    libs = _imports,
)

cc_toolchain(
    name = "x64",
    all_files = ":x64_config",
    ar_files = "@clang_mac_all//:archiver",
    as_files = "@clang_mac_all//:clang",
    compiler_files = ":x64_config",
    dwp_files = "@goldfish_build//toolchains/cc:empty",
    dynamic_runtime_lib = ":dynamic_runtime",
    linker_files = ":x64_config",
    objcopy_files = "@goldfish_build//toolchains/cc:empty",
    static_runtime_lib = ":static_runtime",
    strip_files = "@clang_mac_all//:strip",
    supports_param_files = True,
    toolchain_config = ":x64_config",
)

toolchain(
    name = "x64_toolchain",
    exec_compatible_with = [
        "@platforms//os:macos",
        "@bazel_tools//tools/cpp:clang",
    ],
    target_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:macos",
    ],
    toolchain = ":x64",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

cc_features(
    name = "arm64_features",
    assembler_flags = [
        "--target=arm64-apple-darwin-macho",
        "-mmacos-version-min=11",
        "-no-canonical-prefixes",
        "-D__DATE__=\"redacted\"",
        "-D__TIMESTAMP__=\"redacted\"",
        "-D__TIME__=\"redacted\"",
    ],
    cc_only_link_flags = [
        "-undefined error",  # This is the default.
        "-fobjc-link-runtime",
        "-lc++",
        "-lc++abi",
    ],
    compile_flags = [
        "--target=arm64-apple-darwin-macho",
        "-mmacos-version-min=11",
        "-no-canonical-prefixes",
        "-nostdinc++",
        "-Wno-builtin-macro-redefined",
        "-D__DATE__=\"redacted\"",
        "-D__TIMESTAMP__=\"redacted\"",
        "-D__TIME__=\"redacted\"",
        "-Wall",
        "-Wthread-safety",
        "-Werror=unguarded-availability-new",  # API not available in the targetd OS version.
        "-fstack-protector-strong",
        "-fcolor-diagnostics",
    ] + select({
        "@goldfish_build//toolchains/cc:is_bootstrap": [],
        "//conditions:default": ["-fdebug-prefix-map={BAZEL_EXECUTION_ROOT}=."],
    }),
    cxx_flags = [
        "-std=c++20",
        "-fno-exceptions",
    ],
    link_flags = [
        "--target=arm64-apple-darwin-macho",
        "-mmacos-version-min=11",
        "-fuse-ld=lld",
    ] + select({
        "@goldfish_build//toolchains/cc:is_bootstrap": [],
        "//conditions:default": ["-Wl,-oso_prefix,{BAZEL_EXECUTION_ROOT}/"],
    }),
    toolchain_imports = _imports,
)

cc_toolchain_config(
    name = "arm64_config",
    artifact_name_patterns = [":dylib"],
    cc_features = ":arm64_features",
    cc_tools = [
        "@clang_mac_all//:clang",
        "@clang_mac_all//:clang++",
        "@clang_mac_all//:clang-tidy",
        "@clang_mac_all//:archiver",
        "@clang_mac_all//:strip",
        "@clang_mac_all//:dsymutil",
    ],
    compiler_name = "clang",
    identifier = "macos_clang_arm64",
    sysroot = ":xcode_sdk",
    target_cpu = "arm64",
    toolchain_imports = _imports,
)

cc_toolchain(
    name = "arm64",
    all_files = ":arm64_config",
    ar_files = "@clang_mac_all//:archiver",
    as_files = "@clang_mac_all//:clang",
    compiler_files = ":arm64_config",
    dwp_files = "@goldfish_build//toolchains/cc:empty",
    dynamic_runtime_lib = ":dynamic_runtime",
    linker_files = ":arm64_config",
    objcopy_files = "@goldfish_build//toolchains/cc:empty",
    static_runtime_lib = ":static_runtime",
    strip_files = "@clang_mac_all//:strip",
    supports_param_files = True,
    toolchain_config = ":arm64_config",
)

toolchain(
    name = "arm64_toolchain",
    exec_compatible_with = [
        "@platforms//os:macos",
        "@bazel_tools//tools/cpp:clang",
    ],
    target_compatible_with = [
        "@platforms//cpu:arm64",
        "@platforms//os:macos",
    ],
    toolchain = ":arm64",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

toolchain(
    name = "objcopy_toolchain",
    exec_compatible_with = [
        "@platforms//os:macos",
    ],
    toolchain = "@clang_mac_all//:objcopy",
    toolchain_type = "@goldfish_build//toolchains/cc:objcopy_toolchain_type",
)
