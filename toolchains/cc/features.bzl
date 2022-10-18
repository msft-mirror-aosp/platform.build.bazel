"""Cc toolchain features."""

load("@bazel_skylib//lib:collections.bzl", "collections")
load(":utils.bzl", "flatten", "tee_filter")
load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "feature",
    "flag_group",
    "flag_set",
    "variable_with_value",
    "with_feature_set",
)
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load(
    ":actions.bzl",
    "ARCHIVER_ACTIONS",
    "ASSEMBLE_ACTIONS",
    "CPP_CODEGEN_ACTIONS",
    "CPP_COMPILE_ACTIONS",
    "CPP_SOURCE_ACTIONS",
    "C_COMPILE_ACTIONS",
    "LINK_ACTIONS",
)
load(":cc_toolchain_import.bzl", "CcToolchainImportInfo")

OBJECT_EXTENSIONS = ["o", "obj"]

def toolchain_compile_flags_feature(flags):
    return feature(
        name = "toolchain_compile_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = C_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + ASSEMBLE_ACTIONS,
                flag_groups = [
                    flag_group(flags = flags),
                ],
            ),
        ],
    )

def toolchain_cxx_flags_feature(flags):
    return feature(
        name = "toolchain_cxx_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = CPP_COMPILE_ACTIONS + LINK_ACTIONS,
                flag_groups = [
                    flag_group(flags = flags),
                ],
            ),
        ],
    )

def toolchain_link_flags_feature(flags):
    return feature(
        name = "toolchain_link_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = LINK_ACTIONS,
                flag_groups = [
                    flag_group(flags = flags),
                ],
            ),
        ],
    )

def toolchain_import_feature(import_libs):
    """Creates flags for cc_toolchain_import

    This feature purposefully ignores the (dynamic|static)_runtimes
    as those need to be propagated to the cc_toolchain target.

    Args:
        import_libs: A list of labels to cc_toolchain_import targets.

    Returns:
        A feature to support cc_toolchain_import rule
    """
    include_paths = depset(transitive = [
        lib[CcToolchainImportInfo].include_paths
        for lib in import_libs
    ], order = "topological").to_list()
    dynamic_mode_libs = depset(transitive = [
        lib[CcToolchainImportInfo].dynamic_mode_libraries
        for lib in import_libs
    ], order = "topological").to_list()
    static_mode_libs = depset(transitive = [
        lib[CcToolchainImportInfo].static_mode_libraries
        for lib in import_libs
    ], order = "topological").to_list()
    dynamic_linked_objects, dynamic_mode_libs = tee_filter(
        dynamic_mode_libs,
        lambda f: f.extension in OBJECT_EXTENSIONS,
    )
    static_linked_objects, static_mode_libs = tee_filter(
        static_mode_libs,
        lambda f: f.extension in OBJECT_EXTENSIONS,
    )
    lib_search_paths = collections.uniq([f.dirname for f in dynamic_mode_libs + static_mode_libs])
    dynamic_lib_filenames = collections.uniq([f.basename for f in dynamic_mode_libs])
    static_lib_filenames = collections.uniq([f.basename for f in static_mode_libs])
    so_linked_objects = depset(transitive = [
        lib[CcToolchainImportInfo].so_linked_objects
        for lib in import_libs
    ]).to_list()

    return feature(
        name = "toolchain_import",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = C_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS,
                flag_groups = [
                    flag_group(
                        flags = flatten([
                            ("-isystem", path)
                            for path in include_paths
                        ]),
                    ),
                ],
            ),
            flag_set(
                actions = [ACTION_NAMES.cpp_link_executable],
                flag_groups = [
                    flag_group(
                        flags = ["-L" + p for p in lib_search_paths],
                    ),
                ],
            ),
            flag_set(
                actions = [ACTION_NAMES.cpp_link_executable],
                flag_groups = [
                    flag_group(
                        flags = [obj.path for obj in dynamic_linked_objects],
                    ),
                    flag_group(
                        flags = ["-l:" + f for f in dynamic_lib_filenames],
                    ),
                ],
                with_features = [
                    with_feature_set(features = ["dynamic_linking_mode"]),
                ],
            ),
            flag_set(
                actions = [ACTION_NAMES.cpp_link_executable],
                flag_groups = [
                    flag_group(
                        flags = [obj.path for obj in static_linked_objects],
                    ),
                    flag_group(
                        flags = ["-l:" + f for f in static_lib_filenames],
                    ),
                ],
                with_features = [
                    with_feature_set(features = ["static_linking_mode"]),
                ],
            ),
            flag_set(
                actions = [
                    ACTION_NAMES.cpp_link_dynamic_library,
                    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
                ],
                flag_groups = [
                    flag_group(
                        flags = [obj.path for obj in so_linked_objects],
                    ),
                ],
            ),
        ],
    )

def no_implicit_libs_feature():
    return feature(
        name = "no_implicit_libs",
        flag_sets = [
            flag_set(
                actions = C_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS,
                flag_groups = [
                    flag_group(flags = ["-nostdinc"]),
                ],
            ),
            flag_set(
                actions = CPP_COMPILE_ACTIONS,
                flag_groups = [
                    flag_group(flags = ["-nostdinc++"]),
                ],
            ),
            flag_set(
                actions = LINK_ACTIONS,
                flag_groups = [
                    flag_group(flags = ["-nostdlib"]),
                ],
            ),
        ],
    )

def toolchain_feature_flags():
    return [
        feature(name = "supports_start_end_lib"),
        feature(name = "supports_dynamic_linker"),
        feature(name = "supports_pic"),
        feature(name = "static_link_cpp_runtimes"),
        feature(name = "dynamic_linking_mode"),
        feature(name = "static_linking_mode"),
    ]

def legacy_features_begin():
    """Legacy features moved from their hardcoded Bazel's Java implementation to Starlark.

    These legacy features must come before all other features.
    """
    features = [
        # Legacy features omitted from this list, since they're not used
        # or is alternatively supported through rules directly.
        #
        # Compile related features:
        #
        # legacy_compile_flags
        # per_object_debug_info
        #
        # Optimization related features:
        #
        # fdo_instrument
        # fdo_optimize
        # cs_fdo_instrument
        # cs_fdo_optimize
        # fdo_prefetch_hints
        # autofdo
        # propeller_optimize
        #
        # Interface libraries related features:
        #
        # supports_interface_shared_libraries
        # build_interface_libraries
        # dynamic_library_linker_tool
        #
        # Coverage:
        #
        # coverage
        # llvm_coverage_map_format
        # gcc_coverage_map_format
        #
        # Others:
        #
        # symbol_counts
        # static_libgcc
        # fission_support
        # static_link_cpp_runtimes

        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;l=98;drc=6d03a2ecf25ad596446c296ef1e881b60c379812
        feature(
            name = "dependency_file",
            enabled = True,
            flag_sets = [
                flag_set(
                    actions = C_COMPILE_ACTIONS + CPP_SOURCE_ACTIONS + ASSEMBLE_ACTIONS,
                    flag_groups = [
                        flag_group(
                            expand_if_available = "dependency_file",
                            flags = [
                                "-MD",
                                "-MF",
                                "%{dependency_file}",
                            ],
                        ),
                    ],
                ),
            ],
        ),
        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;drc=6d03a2ecf25ad596446c296ef1e881b60c379812;l=129
        feature(
            name = "random_seed",
            enabled = True,
            flag_sets = [
                flag_set(
                    actions = C_COMPILE_ACTIONS + CPP_CODEGEN_ACTIONS + [ACTION_NAMES.cpp_module_compile],
                    flag_groups = [
                        flag_group(
                            expand_if_available = "output_file",
                            flags = [
                                "-frandom-seed=%{output_file}",
                            ],
                        ),
                    ],
                ),
            ],
        ),
        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;drc=feea781b30788997c0b97ad9103a13fdc3f627c8;l=147
        feature(
            name = "pic",
            enabled = True,
            flag_sets = [
                flag_set(
                    actions = C_COMPILE_ACTIONS + ASSEMBLE_ACTIONS + CPP_CODEGEN_ACTIONS + [
                        ACTION_NAMES.cpp_module_compile,
                        ACTION_NAMES.linkstamp_compile,
                    ],
                    flag_groups = [
                        flag_group(
                            expand_if_available = "pic",
                            flags = ["-fPIC"],
                        ),
                    ],
                ),
            ],
        ),
        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;l=186;drc=6d03a2ecf25ad596446c296ef1e881b60c379812
        feature(
            name = "preprocessor_defines",
            enabled = True,
            flag_sets = [
                flag_set(
                    actions = C_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + ASSEMBLE_ACTIONS,
                    flag_groups = [
                        flag_group(
                            iterate_over = "preprocessor_defines",
                            flags = ["-D%{preprocessor_defines}"],
                        ),
                    ],
                ),
            ],
        ),
        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;l=207;drc=6d03a2ecf25ad596446c296ef1e881b60c379812
        feature(
            name = "includes",
            enabled = True,
            flag_sets = [
                flag_set(
                    actions = CPP_SOURCE_ACTIONS + C_COMPILE_ACTIONS + [
                        ACTION_NAMES.preprocess_assemble,
                        ACTION_NAMES.linkstamp_compile,
                    ],
                    flag_groups = [
                        flag_group(
                            expand_if_available = "includes",
                            iterate_over = "includes",
                            flags = ["-include", "%{includes}"],
                        ),
                    ],
                ),
            ],
        ),
        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;l=232;drc=6d03a2ecf25ad596446c296ef1e881b60c379812
        feature(
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
                            iterate_over = "quote_include_paths",
                            flags = ["-iquote", "%{quote_include_paths}"],
                        ),
                        flag_group(
                            iterate_over = "include_paths",
                            flags = ["-I", "%{include_paths}"],
                        ),
                        flag_group(
                            iterate_over = "system_include_paths",
                            flags = ["-isystem", "%{system_include_paths}"],
                        ),
                        flag_group(
                            iterate_over = "framework_include_paths",
                            flags = ["-F%{framework_include_paths}"],
                        ),
                    ],
                ),
            ],
        ),
        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;l=476;drc=6d03a2ecf25ad596446c296ef1e881b60c379812
        feature(
            name = "shared_flag",
            flag_sets = [
                flag_set(
                    actions = [
                        ACTION_NAMES.cpp_link_dynamic_library,
                        ACTION_NAMES.cpp_link_nodeps_dynamic_library,
                    ],
                    flag_groups = [
                        flag_group(
                            flags = [
                                "-shared",
                            ],
                        ),
                    ],
                ),
            ],
        ),
        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;l=492;drc=6d03a2ecf25ad596446c296ef1e881b60c379812
        feature(
            name = "linkstamps",
            flag_sets = [
                flag_set(
                    actions = LINK_ACTIONS,
                    flag_groups = [
                        flag_group(
                            expand_if_available = "linkstamp_paths",
                            iterate_over = "linkstamp_paths",
                            flags = ["%{linkstamp_paths}"],
                        ),
                    ],
                ),
            ],
        ),
        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;l=512;drc=6d03a2ecf25ad596446c296ef1e881b60c379812
        feature(
            name = "output_execpath_flags",
            flag_sets = [
                flag_set(
                    actions = LINK_ACTIONS,
                    flag_groups = [
                        flag_group(
                            expand_if_available = "output_execpath",
                            flags = ["-o", "%{output_execpath}"],
                        ),
                    ],
                ),
            ],
        ),
        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;drc=feea781b30788997c0b97ad9103a13fdc3f627c8;l=537
        feature(
            name = "runtime_library_search_directories",
            flag_sets = [
                flag_set(
                    actions = LINK_ACTIONS,
                    flag_groups = [
                        flag_group(
                            iterate_over = "runtime_library_search_directories",
                            flag_groups = [
                                flag_group(
                                    flags = [
                                        "-Wl,-rpath,$ORIGIN/%{runtime_library_search_directories}",
                                    ],
                                ),
                            ],
                            expand_if_available =
                                "runtime_library_search_directories",
                        ),
                    ],
                ),
            ],
        ),
        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;l=592;drc=6d03a2ecf25ad596446c296ef1e881b60c379812
        feature(
            name = "library_search_directories",
            flag_sets = [
                flag_set(
                    actions = LINK_ACTIONS,
                    flag_groups = [
                        flag_group(
                            expand_if_available = "library_search_directories",
                            iterate_over = "library_search_directories",
                            flags = ["-L%{library_search_directories}"],
                        ),
                    ],
                ),
            ],
        ),
        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;l=612;drc=6d03a2ecf25ad596446c296ef1e881b60c379812
        feature(
            name = "archiver_flags",
            flag_sets = [
                flag_set(
                    actions = ARCHIVER_ACTIONS,
                    flag_groups = [
                        flag_group(
                            flags = ["rcsD"],
                        ),
                        flag_group(
                            expand_if_available = "output_execpath",
                            flags = ["%{output_execpath}"],
                        ),
                    ],
                ),
                flag_set(
                    actions = ARCHIVER_ACTIONS,
                    flag_groups = [
                        flag_group(
                            expand_if_available = "libraries_to_link",
                            iterate_over = "libraries_to_link",
                            flag_groups = [
                                flag_group(
                                    expand_if_equal = variable_with_value(
                                        name = "libraries_to_link.type",
                                        value = "object_file",
                                    ),
                                    flags = ["%{libraries_to_link.name}"],
                                ),
                            ],
                        ),
                        flag_group(
                            expand_if_equal = variable_with_value(
                                name = "libraries_to_link.type",
                                value = "object_file_group",
                            ),
                            iterate_over = "libraries_to_link.object_files",
                            flags = ["%{libraries_to_link.object_files}"],
                        ),
                    ],
                ),
            ],
        ),
        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;l=653;drc=6d03a2ecf25ad596446c296ef1e881b60c379812
        feature(
            name = "libraries_to_link",
            flag_sets = [
                flag_set(
                    actions = LINK_ACTIONS,
                    flag_groups = ([
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
                                            value = "static_library",
                                        ),
                                        expand_if_true = "libraries_to_link.is_whole_archive",
                                        flags = ["-Wl,-whole-archive"],
                                    ),
                                    flag_group(
                                        expand_if_equal = variable_with_value(
                                            name = "libraries_to_link.type",
                                            value = "object_file_group",
                                        ),
                                        iterate_over = "libraries_to_link.object_files",
                                        flags = ["%{libraries_to_link.object_files}"],
                                    ),
                                    flag_group(
                                        expand_if_equal = variable_with_value(
                                            name = "libraries_to_link.type",
                                            value = "object_file",
                                        ),
                                        flags = ["%{libraries_to_link.name}"],
                                    ),
                                    flag_group(
                                        expand_if_equal = variable_with_value(
                                            name = "libraries_to_link.type",
                                            value = "interface_library",
                                        ),
                                        flags = ["%{libraries_to_link.name}"],
                                    ),
                                    flag_group(
                                        expand_if_equal = variable_with_value(
                                            name = "libraries_to_link.type",
                                            value = "static_library",
                                        ),
                                        flags = ["%{libraries_to_link.name}"],
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
                                            value = "static_library",
                                        ),
                                        expand_if_true = "libraries_to_link.is_whole_archive",
                                        flags = ["-Wl,-no-whole-archive"],
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
                    ]),
                ),
            ],
        ),
        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;drc=feea781b30788997c0b97ad9103a13fdc3f627c8;l=831
        feature(
            name = "force_pic_flags",
            flag_sets = [
                flag_set(
                    actions = [ACTION_NAMES.cpp_link_executable],
                    flag_groups = [
                        flag_group(
                            expand_if_available = "force_pic",
                            iterate_over = "user_link_flags",
                            flags = ["-pie"],
                        ),
                    ],
                ),
            ],
        ),
        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;l=842;drc=6d03a2ecf25ad596446c296ef1e881b60c379812
        feature(
            name = "user_link_flags",
            flag_sets = [
                flag_set(
                    actions = LINK_ACTIONS,
                    flag_groups = [
                        flag_group(
                            expand_if_available = "user_link_flags",
                            iterate_over = "user_link_flags",
                            flags = ["%{user_link_flags}"],
                        ),
                    ],
                ),
            ],
        ),
        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;drc=feea781b30788997c0b97ad9103a13fdc3f627c8;l=924
        feature(
            name = "strip_debug_symbols",
            flag_sets = [
                flag_set(
                    actions = LINK_ACTIONS,
                    flag_groups = [
                        flag_group(
                            expand_if_available = "strip_debug_symbols",
                            flags = ["-Wl,-S"],
                        ),
                    ],
                ),
            ],
        ),
    ]

    return features

def legacy_features_end():
    """Legacy features moved from their hardcoded Bazel's Java implementation to Starlark.

    These legacy features must come after all other features.
    """
    features = [
        # Omitted legacy (unused or re-implemented) features:
        #
        # fully_static_link
        # unfiltered_compile_flags

        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;drc=feea781b30788997c0b97ad9103a13fdc3f627c8;l=1407
        feature(
            name = "user_compile_flags",
            enabled = True,
            flag_sets = [
                flag_set(
                    actions = C_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + ASSEMBLE_ACTIONS,
                    flag_groups = [
                        flag_group(
                            expand_if_available = "user_compile_flags",
                            iterate_over = "user_compile_flags",
                            flags = ["%{user_compile_flags}"],
                        ),
                    ],
                ),
            ],
        ),
        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;drc=feea781b30788997c0b97ad9103a13fdc3f627c8;l=1432
        feature(
            name = "sysroot",
            enabled = True,
            flag_sets = [
                flag_set(
                    actions = C_COMPILE_ACTIONS + CPP_SOURCE_ACTIONS + LINK_ACTIONS + [
                        ACTION_NAMES.preprocess_assemble,
                        ACTION_NAMES.linkstamp_compile,
                    ],
                    flag_groups = [
                        flag_group(
                            expand_if_available = "sysroot",
                            flags = ["--sysroot=%{sysroot}"],
                        ),
                    ],
                ),
            ],
        ),
        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;drc=feea781b30788997c0b97ad9103a13fdc3f627c8;l=1490
        feature(
            name = "linker_param_file",
            flag_sets = [
                flag_set(
                    actions = LINK_ACTIONS + ARCHIVER_ACTIONS,
                    flag_groups = [
                        flag_group(
                            expand_if_available = "linker_param_file",
                            flags = ["@%{linker_param_file}"],
                        ),
                    ],
                ),
            ],
        ),
        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;l=1511;drc=6d03a2ecf25ad596446c296ef1e881b60c379812
        feature(
            name = "compiler_input_flags",
            enabled = True,
            flag_sets = [
                flag_set(
                    actions = C_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + ASSEMBLE_ACTIONS,
                    flag_groups = [
                        flag_group(
                            expand_if_available = "source_file",
                            flags = ["-c", "%{source_file}"],
                        ),
                    ],
                ),
            ],
        ),
        # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CppActionConfigs.java;l=1538;drc=6d03a2ecf25ad596446c296ef1e881b60c379812
        feature(
            name = "compiler_output_flags",
            enabled = True,
            flag_sets = [
                flag_set(
                    actions = C_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + ASSEMBLE_ACTIONS,
                    flag_groups = [
                        flag_group(
                            expand_if_available = "output_assembly_file",
                            flags = ["-S"],
                        ),
                        flag_group(
                            expand_if_available = "output_preprocess_file",
                            flags = ["-E"],
                        ),
                        flag_group(
                            expand_if_available = "output_file",
                            flags = ["-o", "%{output_file}"],
                        ),
                    ],
                ),
            ],
        ),
    ]

    return features
