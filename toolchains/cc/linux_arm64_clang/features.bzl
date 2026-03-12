"""Cc toolchain features that works with clang for ARM Linux."""

load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "feature",
    "flag_group",
    "flag_set",
)
load(
    "//toolchains/cc:actions.bzl",
    "CPP_COMPILE_ACTIONS",
    "C_COMPILE_ACTIONS",
    "LINK_ACTIONS",
)
load(
    "//toolchains/cc:features_common.bzl",
    "dynamic_linking_mode_feature",
    "get_disable_all_warnings_feature",
    "get_reproducible_build_feature",
    "get_toolchain_assembler_flags_feature",
    "get_toolchain_cc_only_features",
    "get_toolchain_compile_flags_feature",
    "get_toolchain_cxx_flags_feature",
    "get_toolchain_link_flags_feature",
    "get_warnings_as_errors_feature",
    "get_warnings_feature",
    "linkstamps_feature",
    "no_legacy_features",
    "static_link_cpp_runtimes_feature",
    "static_linking_mode_feature",
    "strip_flags_feature",
    "supports_dynamic_linker_feature",
    "supports_pic_feature",
    "supports_start_end_lib_feature",
    "toolchain_import_configs",
    "user_compile_flags_feature",
    "user_link_flags_feature",
)
load(
    "//toolchains/cc:rules.bzl",
    "CcFeatureConfigInfo",
    "CcToolchainImportInfo",
)
load(
    "//toolchains/cc:utils.bzl",
    "flatten",
)
load(
    "//toolchains/cc/linux_clang:features.bzl",
    "archiver_flags_feature",
    "asan_feature",
    "compiler_input_feature",
    "compiler_output_feature",
    "dbg_feature",
    "dependency_file_feature",
    "fastbuild_feature",
    "force_pic_feature",
    "generate_debug_symbols_feature",
    "get_toolchain_include_paths_feature",
    "get_toolchain_lib_search_paths_feature",
    "include_paths_feature",
    "includes_feature",
    "lib_search_paths_feature",
    "libraries_to_link_feature",
    "linker_param_file_feature",
    "opt_feature",
    "output_execpath_feature",
    "pic_feature",
    "preprocessor_defines_feature",
    "random_seed_feature",
    "rpath_feature",
    "shared_flag_feature",
    "strip_debug_symbols_feature",
    "sysroot_feature",
    "thinlto_feature",
    "tsan_feature",
)

reproducible_build_feature = get_reproducible_build_feature(
    compile_flags = [
        "-Wno-builtin-macro-redefined",
        "-D__DATE__=\"redacted\"",
        "-D__TIMESTAMP__=\"redacted\"",
        "-D__TIME__=\"redacted\"",
        "-no-canonical-prefixes",
        "-nostdinc++",
    ],
)

def _cc_features_impl(ctx):
    import_config = toolchain_import_configs(ctx.attr.toolchain_imports)

    target_triple_feature = feature(
        name = "target_triple",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = C_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + LINK_ACTIONS,
                flag_groups = [
                    flag_group(
                        flags = ["--target=aarch64-none-linux-gnu"],
                    ),
                ],
            ),
        ],
    )

    all_features = flatten([
        target_triple_feature,
        no_legacy_features,
        dynamic_linking_mode_feature,
        static_linking_mode_feature,
        supports_start_end_lib_feature,
        supports_dynamic_linker_feature,
        supports_pic_feature,
        static_link_cpp_runtimes_feature,
        dependency_file_feature,
        random_seed_feature,
        pic_feature,
        preprocessor_defines_feature,
        get_toolchain_include_paths_feature(import_config),
        includes_feature,
        include_paths_feature,
        thinlto_feature,
        shared_flag_feature,
        linkstamps_feature,
        output_execpath_feature,
        rpath_feature,
        lib_search_paths_feature,
        get_toolchain_lib_search_paths_feature(import_config),
        archiver_flags_feature,
        strip_flags_feature,
        generate_debug_symbols_feature,
        opt_feature,
        dbg_feature,
        fastbuild_feature,
        asan_feature,
        tsan_feature,
        libraries_to_link_feature,
        get_toolchain_link_flags_feature(ctx.attr.link_flags),
        get_toolchain_cc_only_features(ctx.attr.cc_only_link_flags),
        get_toolchain_assembler_flags_feature(ctx.attr.assembler_flags),
        user_link_flags_feature,
        force_pic_feature,
        strip_debug_symbols_feature,
        get_toolchain_compile_flags_feature(ctx.attr.compile_flags),
        get_toolchain_cxx_flags_feature(ctx.attr.cxx_flags),
        user_compile_flags_feature,
        reproducible_build_feature,
        get_disable_all_warnings_feature(),
        get_warnings_feature(),
        get_warnings_as_errors_feature(),
        sysroot_feature,
        linker_param_file_feature,
        compiler_input_feature,
        compiler_output_feature,
    ])
    return CcFeatureConfigInfo(features = all_features)

cc_features = rule(
    implementation = _cc_features_impl,
    doc = "A rule to create features for cc toolchain config.",
    attrs = {
        "assembler_flags": attr.string_list(
            doc = "Flags always added to assembler actions.",
            default = [],
        ),
        "compile_flags": attr.string_list(
            doc = "Flags always added to compile actions.",
            default = [],
        ),
        "cxx_flags": attr.string_list(
            doc = "Flags always added to c++ actions.",
            default = [],
        ),
        "link_flags": attr.string_list(
            doc = "Flags always added to link actions.",
            default = [],
        ),
        "cc_only_link_flags": attr.string_list(
            doc = "Flags added to link actions only when linking cc binaries.",
            default = [],
        ),
        "toolchain_imports": attr.label_list(
            doc = "A list of cc_toolchain_import targets.",
            providers = [CcToolchainImportInfo],
            default = [],
        ),
    },
    provides = [CcFeatureConfigInfo],
)
