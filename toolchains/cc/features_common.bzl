"""Common cc toolchain features independent of compilers."""

load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "feature",
    "feature_set",
    "flag_group",
    "flag_set",
)
load(
    ":actions.bzl",
    "ASSEMBLE_ACTIONS",
    "CPP_COMPILE_ACTIONS",
    "C_COMPILE_ACTIONS",
    "LINK_ACTIONS",
)
load(":rules.bzl", "CcToolchainImportInfo")
load(":utils.bzl", "check_args", "filter_none")

# A feature set that is satisfied only when we are linking c / cpp code.
# This leverages the fact that certain features are disabled by rules_rust when
# linking pure-rust with the toolchain.
LINK_CC_ONLY = feature_set(features = ["rules_rust_link_cc"])

def toolchain_import_configs(import_libs):
    """Convert cc_toolchain_import targets to configs for features.

    This feature purposefully ignores the (dynamic|static)_runtimes
    as those need to be propagated to the cc_toolchain target.

    Args:
        import_libs: A list of labels to cc_toolchain_import targets.

    Returns:
        A struct containing the paths to be consumed by feature definition.
    """
    include_paths = depset(transitive = [
        lib[CcToolchainImportInfo].include_paths
        for lib in import_libs
    ], order = "topological").to_list()
    framework_paths = depset(transitive = [
        lib[CcToolchainImportInfo].framework_paths
        for lib in import_libs
    ], order = "topological").to_list()
    lib_search_paths = depset(transitive = [
        lib[CcToolchainImportInfo].lib_search_paths
        for lib in import_libs
    ], order = "topological").to_list()

    return struct(
        include_paths = include_paths,
        framework_paths = framework_paths,
        lib_search_paths = lib_search_paths,
    )

def toolchain_import_files(import_libs):
    toolchain_import_files = [
        lib[DefaultInfo].files
        for lib in import_libs
    ]
    return depset(transitive = toolchain_import_files)

def get_toolchain_compile_flags_feature(flags):
    return feature(
        name = "toolchain_compile_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = C_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + ASSEMBLE_ACTIONS,
                flag_groups = filter_none([
                    check_args(len, flag_group, flags = flags),
                ]),
            ),
        ],
    )

def get_toolchain_cxx_flags_feature(flags):
    return feature(
        name = "toolchain_cxx_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = CPP_COMPILE_ACTIONS,
                flag_groups = filter_none([
                    check_args(len, flag_group, flags = flags),
                ]),
            ),
        ],
    )

def get_toolchain_link_flags_feature(flags):
    return feature(
        name = "toolchain_link_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = LINK_ACTIONS,
                flag_groups = filter_none([
                    check_args(len, flag_group, flags = flags),
                ]),
            ),
        ],
    )

def get_toolchain_cc_only_features(flags):
    return [
        feature(
            name = "toolchain_cc_only_link_flags",
            enabled = True,
            flag_sets = [
                flag_set(
                    actions = LINK_ACTIONS,
                    flag_groups = filter_none([
                        check_args(len, flag_group, flags = flags),
                    ]),
                ),
            ],
            requires = [LINK_CC_ONLY],
        ),
    ] + [
        feature(
            name = name,
            enabled = True,
        )
        for name in LINK_CC_ONLY.features
    ]

def get_b_prefix_feature(file):
    return feature(
        name = "b_prefix",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = C_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + LINK_ACTIONS,
                flag_groups = filter_none([
                    check_args(
                        len,
                        flag_group,
                        flags = ["-B", file.path] if file else [],
                    ),
                ]),
            ),
        ],
    )

no_legacy_features = feature(
    name = "no_legacy_features",
    enabled = True,
)

no_stripping_feature = feature(
    name = "no_stripping",
    enabled = True,
)

supports_start_end_lib_feature = feature(
    name = "supports_start_end_lib",
    enabled = True,
)

supports_dynamic_linker_feature = feature(
    name = "supports_dynamic_linker",
    enabled = True,
)

supports_pic_feature = feature(
    name = "supports_pic",
    enabled = True,
)

static_link_cpp_runtimes_feature = feature(
    name = "static_link_cpp_runtimes",
    enabled = True,
    requires = [LINK_CC_ONLY],
)

dynamic_linking_mode_feature = feature(
    name = "dynamic_linking_mode",
)

static_linking_mode_feature = feature(
    name = "static_linking_mode",
)

linkstamps_feature = feature(
    name = "linkstamps",
    enabled = True,
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
)

user_link_flags_feature = feature(
    name = "user_link_flags",
    enabled = True,
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
)

user_compile_flags_feature = feature(
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
)
