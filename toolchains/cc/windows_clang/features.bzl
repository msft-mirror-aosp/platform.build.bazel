"""Cc toolchain features that works with clang-cl."""

load(
    "@//build/bazel/toolchains/cc:utils.bzl",
    "check_args",
    "filter_none",
    "flatten",
)
load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "env_entry",
    "env_set",
    "feature",
    "flag_group",
    "flag_set",
    "variable_with_value",
    "with_feature_set",
)
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load(
    "@//build/bazel/toolchains/cc:actions.bzl",
    "ARCHIVER_ACTIONS",
    "ASSEMBLE_ACTIONS",
    "CPP_COMPILE_ACTIONS",
    "CPP_SOURCE_ACTIONS",
    "C_COMPILE_ACTIONS",
    "LINK_ACTIONS",
)
load(
    "@//build/bazel/toolchains/cc:rules.bzl",
    "CcFeatureConfigInfo",
    "CcToolchainImportInfo",
)
load(
    "@//build/bazel/toolchains/cc:features_common.bzl",
    "OBJECT_EXTENSIONS_WINDOWS",
    "dynamic_linking_mode_feature",
    "get_toolchain_compile_flags_feature",
    "get_toolchain_cxx_flags_feature",
    "get_toolchain_link_flags_feature",
    "linkstamps_feature",
    "no_legacy_features",
    "no_stripping_feature",
    "static_linking_mode_feature",
    "supports_dynamic_linker_feature",
    "supports_start_end_lib_feature",
    "toolchain_import_configs",
    "user_compile_flags_feature",
    "user_link_flags_feature",
)
load(
    "@//build/bazel/toolchains/cc/linux_clang:features.bzl",
    "linker_param_file_feature",
)

archive_param_file_feature = feature(
    name = "archive_param_file",
    enabled = True,
)

compiler_input_feature = feature(
    name = "compiler_input_flags",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = C_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + ASSEMBLE_ACTIONS,
            flag_groups = [
                flag_group(
                    expand_if_available = "source_file",
                    flags = ["/c", "%{source_file}"],
                ),
            ],
        ),
    ],
)

compiler_output_feature = feature(
    name = "compiler_output_flags",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = C_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + ASSEMBLE_ACTIONS,
            flag_groups = [
                flag_group(
                    expand_if_available = "output_file",
                    expand_if_not_available = "output_preprocess_file",
                    flag_groups = [
                        flag_group(
                            expand_if_not_available = "output_assembly_file",
                            flags = ["/Fo%{output_file}"],
                        ),
                    ],
                ),
                flag_group(
                    expand_if_available = "output_file",
                    flag_groups = [
                        flag_group(
                            expand_if_available = "output_assembly_file",
                            flags = ["/Fa%{output_file}"],
                        ),
                        flag_group(
                            expand_if_available = "output_preprocess_file",
                            flags = ["/P", "/Fi%{output_file}"],
                        ),
                    ],
                ),
            ],
        ),
    ],
)

compiler_param_file_feature = feature(
    name = "compiler_param_file",
    enabled = True,
)

copy_dynamic_libraries_to_binary_feature = feature(
    name = "copy_dynamic_libraries_to_binary",
    enabled = True,
)

dbg_feature = feature(
    name = "dbg",
    flag_sets = [
        flag_set(
            actions = C_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS,
            flag_groups = [
                flag_group(flags = ["/Od", "/Z7"]),
            ],
        ),
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [
                flag_group(flags = ["/INCREMENTAL:NO"]),
            ],
        ),
    ],
    implies = ["generate_pdb_file"],
)

def_file_feature = feature(
    name = "def_file",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [
                flag_group(
                    flags = ["/DEF:%{def_file_path}"],
                    expand_if_available = "def_file_path",
                ),
            ],
        ),
    ],
)

dynamic_link_cpp_runtimes_feature = feature(
    name = "dynamic_link_cpp_runtimes",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
            flag_groups = [flag_group(flags = ["/MD"])],
            with_features = [with_feature_set(not_features = ["dbg"])],
        ),
        flag_set(
            actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
            flag_groups = [flag_group(flags = ["/MDd"])],
            with_features = [with_feature_set(features = ["dbg"])],
        ),
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [flag_group(flags = ["/DEFAULTLIB:msvcrt.lib"])],
            with_features = [with_feature_set(not_features = ["dbg"])],
        ),
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [flag_group(flags = ["/DEFAULTLIB:msvcrtd.lib"])],
            with_features = [with_feature_set(features = ["dbg"])],
        ),
    ],
    provides = ["runtime_select"],
)

external_include_paths_feature = feature(
    name = "external_include_paths",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = CPP_SOURCE_ACTIONS + C_COMPILE_ACTIONS + [
                ACTION_NAMES.preprocess_assemble,
                ACTION_NAMES.linkstamp_compile,
            ],
            flag_groups = [
                flag_group(
                    flags = ["/external:I%{external_include_paths}"],
                    iterate_over = "external_include_paths",
                    expand_if_available = "external_include_paths",
                ),
            ],
        ),
    ],
)

generate_pdb_file_feature = feature(
    name = "generate_pdb_file",
    flag_sets = [
        flag_set(
            actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
            flag_groups = [flag_group(flags = ["/Zi"])],
        ),
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [flag_group(flags = ["/DEBUG"])],
        ),
    ],
)

def get_archiver_flags_feature(user_flags):
    return feature(
        name = "archiver_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = ARCHIVER_ACTIONS,
                flag_groups = filter_none([
                    check_args(len, flag_group, flags = user_flags),
                ]) + [
                    flag_group(
                        expand_if_available = "output_execpath",
                        flags = ["/OUT:%{output_execpath}"],
                    ),
                    flag_group(
                        expand_if_available = "libraries_to_link",
                        iterate_over = "libraries_to_link",
                        flag_groups = [
                            flag_group(
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file_group",
                                ),
                                iterate_over = "libraries_to_link.object_files",
                                flag_groups = [
                                    flag_group(flags = ["%{libraries_to_link.object_files}"]),
                                ],
                            ),
                            flag_group(
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file",
                                ),
                                flag_groups = [
                                    flag_group(flags = ["%{libraries_to_link.name}"]),
                                ],
                            ),
                            flag_group(
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "static_library",
                                ),
                                flag_groups = [
                                    flag_group(flags = ["%{libraries_to_link.name}"]),
                                ],
                            ),
                        ],
                    ),
                ],
            ),
        ],
    )

def get_toolchain_include_paths_feature(import_config):
    return feature(
        name = "toolchain_include_paths",
        enabled = True,
        env_sets = [
            env_set(
                actions = CPP_SOURCE_ACTIONS + C_COMPILE_ACTIONS + [
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.linkstamp_compile,
                ],
                env_entries = [
                    env_entry(
                        key = "INCLUDE",
                        value = ";".join(import_config.include_paths),
                    ),
                ],
            ),
        ],
    )

def get_toolchain_lib_search_paths_feature(import_config):
    return feature(
        name = "toolchain_library_search_directories",
        enabled = True,
        env_sets = [
            env_set(
                actions = LINK_ACTIONS,
                env_entries = [
                    env_entry(
                        key = "LIB",
                        value = ";".join(import_config.lib_search_paths),
                    ),
                ],
            ),
        ],
    )

def get_toolchain_libraries_to_link_feature(import_config):
    return feature(
        name = "toolchain_libraries_to_link",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = LINK_ACTIONS,
                flag_groups = filter_none([
                    check_args(
                        len,
                        flag_group,
                        flags = [str(obj.path) for obj in import_config.dynamic_linked_objects],
                    ),
                ]),
                with_features = [
                    with_feature_set(features = ["dynamic_linking_mode"]),
                ],
            ),
            flag_set(
                actions = LINK_ACTIONS,
                flag_groups = filter_none([
                    check_args(
                        len,
                        flag_group,
                        flags = [str(obj.path) for obj in import_config.static_linked_objects],
                    ),
                ]),
                with_features = [
                    with_feature_set(features = ["static_linking_mode"]),
                ],
            ),
        ],
    )

has_configured_linker_path_feature = feature(
    name = "has_configured_linker_path",
    enabled = True,
)

include_paths_feature = feature(
    name = "include_paths",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = CPP_SOURCE_ACTIONS + C_COMPILE_ACTIONS + [
                ACTION_NAMES.preprocess_assemble,
                ACTION_NAMES.linkstamp_compile,
            ],
            flag_groups = [
                flag_group(
                    flags = ["/I%{quote_include_paths}"],
                    iterate_over = "quote_include_paths",
                ),
                flag_group(
                    flags = ["/I%{include_paths}"],
                    iterate_over = "include_paths",
                ),
                flag_group(
                    flags = ["/I%{system_include_paths}"],
                    iterate_over = "system_include_paths",
                ),
            ],
        ),
    ],
)

interface_library_output_feature = feature(
    name = "interface_library_output_path",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = [
                ACTION_NAMES.cpp_link_dynamic_library,
                ACTION_NAMES.cpp_link_nodeps_dynamic_library,
            ],
            flag_groups = [
                flag_group(
                    expand_if_available = "interface_library_output_path",
                    flags = ["/IMPLIB:%{interface_library_output_path}"],
                ),
            ],
        ),
    ],
)

libraries_to_link_feature = feature(
    name = "libraries_to_link",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [
                flag_group(
                    expand_if_available = "libraries_to_link",
                    iterate_over = "libraries_to_link",
                    flag_groups = [
                        flag_group(
                            expand_if_equal = variable_with_value(
                                name = "libraries_to_link.type",
                                value = "object_file_group",
                            ),
                            expand_if_false = "libraries_to_link.is_whole_archive",
                            flags = ["/start-lib"],
                        ),
                        flag_group(
                            expand_if_equal = variable_with_value(
                                name = "libraries_to_link.type",
                                value = "object_file_group",
                            ),
                            iterate_over = "libraries_to_link.object_files",
                            flag_groups = [
                                flag_group(flags = ["%{libraries_to_link.object_files}"]),
                            ],
                        ),
                        flag_group(
                            expand_if_equal = variable_with_value(
                                name = "libraries_to_link.type",
                                value = "object_file_group",
                            ),
                            expand_if_false = "libraries_to_link.is_whole_archive",
                            flags = ["/end-lib"],
                        ),
                        flag_group(
                            expand_if_equal = variable_with_value(
                                name = "libraries_to_link.type",
                                value = "object_file",
                            ),
                            flag_groups = [
                                flag_group(flags = ["%{libraries_to_link.name}"]),
                            ],
                        ),
                        flag_group(
                            expand_if_equal = variable_with_value(
                                name = "libraries_to_link.type",
                                value = "interface_library",
                            ),
                            flag_groups = [
                                flag_group(flags = ["%{libraries_to_link.name}"]),
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
                                    flags = ["/WHOLEARCHIVE:%{libraries_to_link.name}"],
                                ),
                            ],
                        ),
                    ],
                ),
            ],
        ),
    ],
)

no_windows_export_all_symbols_feature = feature(name = "no_windows_export_all_symbols")

opt_feature = feature(
    name = "opt",
    flag_sets = [
        flag_set(
            actions = C_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS,
            flag_groups = [
                flag_group(flags = [
                    "/O2",
                    # Allow removal of unused sections and code folding at link
                    # time.
                    "/Gy",
                    "/Gw",
                ]),
            ],
        ),
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [
                flag_group(flags = [
                    # Control flow guards
                    "/GUARD:CF",
                    "/OPT:REF",
                    "/OPT:ICF",
                ]),
            ],
        ),
    ],
)

output_execpath_feature = feature(
    name = "output_execpath_flags",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [
                flag_group(
                    flags = ["/OUT:%{output_execpath}"],
                    expand_if_available = "output_execpath",
                ),
            ],
        ),
    ],
)

parse_showincludes_feature = feature(
    name = "parse_showincludes",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = C_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + ASSEMBLE_ACTIONS,
            flag_groups = [flag_group(flags = ["/showIncludes"])],
        ),
    ],
)

preprocessor_defines_feature = feature(
    name = "preprocessor_defines",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = C_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + ASSEMBLE_ACTIONS,
            flag_groups = [
                flag_group(
                    iterate_over = "preprocessor_defines",
                    flags = ["/D%{preprocessor_defines}"],
                ),
            ],
        ),
    ],
)

shared_flag_feature = feature(
    name = "shared_flag",
    enabled = True,
    flag_sets = [
        flag_set(
            actions = [
                ACTION_NAMES.cpp_link_dynamic_library,
                ACTION_NAMES.cpp_link_nodeps_dynamic_library,
            ],
            flag_groups = [flag_group(flags = ["/DLL"])],
        ),
    ],
)

static_link_cpp_runtimes_feature = feature(
    name = "static_link_cpp_runtimes",
    flag_sets = [
        flag_set(
            actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
            flag_groups = [flag_group(flags = ["/MT"])],
            with_features = [with_feature_set(not_features = ["dbg"])],
        ),
        flag_set(
            actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
            flag_groups = [flag_group(flags = ["/MTd"])],
            with_features = [with_feature_set(features = ["dbg"])],
        ),
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [flag_group(flags = ["/DEFAULTLIB:libcmt.lib"])],
            with_features = [with_feature_set(not_features = ["dbg"])],
        ),
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = [flag_group(flags = ["/DEFAULTLIB:libcmtd.lib"])],
            with_features = [with_feature_set(features = ["dbg"])],
        ),
    ],
    provides = ["runtime_select"],
)

supports_interface_shared_libraries_feature = feature(
    name = "supports_interface_shared_libraries",
    enabled = True,
)

targets_windows_feature = feature(
    name = "targets_windows",
    enabled = True,
)

windows_export_all_symbols_feature = feature(
    name = "windows_export_all_symbols",
    enabled = True,
)

def _cc_features_impl(ctx):
    import_config = toolchain_import_configs(
        ctx.attr.toolchain_imports,
        OBJECT_EXTENSIONS_WINDOWS,
    )
    all_features = flatten([
        # features set / consumed by bazel
        no_legacy_features,
        no_stripping_feature,
        dynamic_linking_mode_feature,
        static_linking_mode_feature,
        supports_start_end_lib_feature,
        supports_dynamic_linker_feature,
        supports_interface_shared_libraries_feature,
        has_configured_linker_path_feature,
        archive_param_file_feature,
        compiler_param_file_feature,
        copy_dynamic_libraries_to_binary_feature,
        targets_windows_feature,
        windows_export_all_symbols_feature,
        no_windows_export_all_symbols_feature,

        # features for tool invocations
        preprocessor_defines_feature,
        parse_showincludes_feature,
        include_paths_feature,
        external_include_paths_feature,
        get_toolchain_include_paths_feature(import_config),
        shared_flag_feature,
        linkstamps_feature,
        output_execpath_feature,
        interface_library_output_feature,
        def_file_feature,
        dynamic_link_cpp_runtimes_feature,
        static_link_cpp_runtimes_feature,
        generate_pdb_file_feature,
        get_toolchain_lib_search_paths_feature(import_config),
        get_archiver_flags_feature(ctx.attr.archive_flags),
        # Start flag ordering: the order of following features impacts how
        # flags override each other.
        opt_feature,
        dbg_feature,
        libraries_to_link_feature,
        get_toolchain_link_flags_feature(ctx.attr.link_flags),
        user_link_flags_feature,
        get_toolchain_libraries_to_link_feature(import_config),
        get_toolchain_compile_flags_feature(ctx.attr.compile_flags),
        get_toolchain_cxx_flags_feature(ctx.attr.cxx_flags),
        user_compile_flags_feature,
        ### End flag ordering ##
        linker_param_file_feature,
        compiler_input_feature,
        compiler_output_feature,
    ])
    return CcFeatureConfigInfo(features = all_features)

cc_features = rule(
    implementation = _cc_features_impl,
    doc = "A rule to create features for cc toolchain config.",
    attrs = {
        "archive_flags": attr.string_list(
            doc = "Flags always added to archive actions.",
            default = [],
        ),
        "compile_flags": attr.string_list(
            doc = "Flags always added to compile actions.",
            default = [],
        ),
        "cxx_flags": attr.string_list(
            doc = "Flags always added to c++ compile actions.",
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
