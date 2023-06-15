"""Cc toolchain features that works with clang."""

load(
    "@//build/bazel/toolchains/cc:utils.bzl",
    "flatten",
)
load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "feature",
    "flag_group",
    "flag_set",
    "variable_with_value",
)
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load(
    "@//build/bazel/toolchains/cc:actions.bzl",
    "LINK_ACTIONS",
)
load(
    "@//build/bazel/toolchains/cc:rules.bzl",
    "CcFeatureConfigInfo",
    "CcToolchainImportInfo",
)
load(
    "@//build/bazel/toolchains/cc:features_common.bzl",
    "OBJECT_EXTENSIONS_UNIX",
    "dynamic_linking_mode_feature",
    "get_toolchain_compile_flags_feature",
    "get_toolchain_cxx_flags_feature",
    "get_toolchain_link_flags_feature",
    "linkstamps_feature",
    "no_legacy_features",
    "static_link_cpp_runtimes_feature",
    "static_linking_mode_feature",
    "supports_dynamic_linker_feature",
    "supports_pic_feature",
    "supports_start_end_lib_feature",
    "toolchain_import_configs",
    "user_compile_flags_feature",
    "user_link_flags_feature",
)
load(
    "@//build/bazel/toolchains/cc/linux_clang:features.bzl",
    "archiver_flags_feature",
    "compiler_input_feature",
    "compiler_output_feature",
    "dependency_file_feature",
    "get_toolchain_include_paths_feature",
    "get_toolchain_lib_search_paths_feature",
    "get_toolchain_libraries_to_link_feature",
    "include_paths_feature",
    "includes_feature",
    "lib_search_paths_feature",
    "linker_param_file_feature",
    "output_execpath_feature",
    "pic_feature",
    "preprocessor_defines_feature",
    "random_seed_feature",
    "shared_flag_feature",
    "strip_debug_symbols_feature",
    "sysroot_feature",
)

# https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;drc=feea781b30788997c0b97ad9103a13fdc3f627c8;l=537
rpath_feature = feature(
    name = "runtime_library_search_directories",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [
                flag_group(
                    iterate_over = "runtime_library_search_directories",
                    flag_groups = [
                        flag_group(
                            flags = [
                                "-Wl,-rpath,@loader_path/%{runtime_library_search_directories}",
                            ],
                        ),
                    ],
                    expand_if_available =
                        "runtime_library_search_directories",
                ),
            ],
        ),
    ],
)

# https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;l=653;drc=6d03a2ecf25ad596446c296ef1e881b60c379812
libraries_to_link_feature = feature(
    name = "libraries_to_link",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [
                flag_group(
                    expand_if_true = "thinlto_param_file",
                    flags = ["-Wl,@%{thinlto_param_file}"],
                ),
                flag_group(
                    expand_if_available = "libraries_to_link",
                    iterate_over = "libraries_to_link",
                    flag_groups = (
                        [
                            flag_group(
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file_group",
                                ),
                                expand_if_false = "libraries_to_link.is_whole_archive",
                                flags = ["-Wl,--start-lib"],
                            ),
                            flag_group(
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file_group",
                                ),
                                iterate_over = "libraries_to_link.object_files",
                                flag_groups = [
                                    flag_group(
                                        expand_if_false = "libraries_to_link.is_whole_archive",
                                        flags = ["%{libraries_to_link.object_files}"],
                                    ),
                                    flag_group(
                                        expand_if_true = "libraries_to_link.is_whole_archive",
                                        flags = ["-Wl,-force_load,%{libraries_to_link.object_files}"],
                                    ),
                                ],
                            ),
                            flag_group(
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file",
                                ),
                                flag_groups = [
                                    flag_group(
                                        expand_if_false = "libraries_to_link.is_whole_archive",
                                        flags = ["%{libraries_to_link.name}"],
                                    ),
                                    flag_group(
                                        expand_if_true = "libraries_to_link.is_whole_archive",
                                        flags = ["-Wl,-force_load,%{libraries_to_link.name}"],
                                    ),
                                ],
                            ),
                            flag_group(
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "interface_library",
                                ),
                                flag_groups = [
                                    flag_group(
                                        expand_if_false = "libraries_to_link.is_whole_archive",
                                        flags = ["%{libraries_to_link.name}"],
                                    ),
                                    flag_group(
                                        expand_if_true = "libraries_to_link.is_whole_archive",
                                        flags = ["-Wl,-force_load,%{libraries_to_link.name}"],
                                    ),
                                ],
                            ),
                            flag_group(
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "static_library",
                                ),
                                flag_groups = [
                                    flag_group(
                                        expand_if_false = "libraries_to_link.is_whole_archive",
                                        flags = ["%{libraries_to_link.name}"],
                                    ),
                                    flag_group(
                                        expand_if_true = "libraries_to_link.is_whole_archive",
                                        flags = ["-Wl,-force_load,%{libraries_to_link.name}"],
                                    ),
                                ],
                            ),
                            flag_group(
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "dynamic_library",
                                ),
                                flags = ["-l%{libraries_to_link.name}"],
                            ),
                            flag_group(
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "versioned_dynamic_library",
                                ),
                                flags = ["-l:%{libraries_to_link.name}"],
                            ),
                            flag_group(
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file_group",
                                ),
                                expand_if_false = "libraries_to_link.is_whole_archive",
                                flags = ["-Wl,--end-lib"],
                            ),
                        ]
                    ),
                ),
            ],
        ),
    ],
)

# https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;drc=feea781b30788997c0b97ad9103a13fdc3f627c8;l=831
force_pic_feature = feature(
    name = "force_pic_flags",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = [ACTION_NAMES.cpp_link_executable],
            flag_groups = [
                flag_group(
                    expand_if_available = "force_pic",
                    iterate_over = "user_link_flags",
                    flags = ["-Wl,-pie"],
                ),
            ],
        ),
    ],
)

def _cc_features_impl(ctx):
    import_config = toolchain_import_configs(
        ctx.attr.toolchain_imports,
        OBJECT_EXTENSIONS_UNIX,
    )
    all_features = flatten([
        # features set / consumed by bazel
        no_legacy_features,
        dynamic_linking_mode_feature,
        static_linking_mode_feature,
        supports_start_end_lib_feature,
        supports_dynamic_linker_feature,
        supports_pic_feature,
        static_link_cpp_runtimes_feature,
        # features for tool invocations
        dependency_file_feature,
        random_seed_feature,
        pic_feature,
        preprocessor_defines_feature,
        includes_feature,
        include_paths_feature,
        get_toolchain_include_paths_feature(import_config),
        shared_flag_feature,
        linkstamps_feature,
        output_execpath_feature,
        rpath_feature,
        lib_search_paths_feature,
        get_toolchain_lib_search_paths_feature(import_config),
        archiver_flags_feature,
        libraries_to_link_feature,
        get_toolchain_libraries_to_link_feature(import_config),
        force_pic_feature,
        get_toolchain_link_flags_feature(ctx.attr.link_flags),
        user_link_flags_feature,
        strip_debug_symbols_feature,
        get_toolchain_compile_flags_feature(ctx.attr.compile_flags),
        get_toolchain_cxx_flags_feature(ctx.attr.cxx_flags),
        user_compile_flags_feature,
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
        "toolchain_imports": attr.label_list(
            doc = "A list of cc_toolchain_import targets.",
            providers = [CcToolchainImportInfo],
            default = [],
        ),
    },
    provides = [CcFeatureConfigInfo],
)
