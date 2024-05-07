"""Common cc toolchain features independent of compilers."""

load("@bazel_skylib//lib:collections.bzl", "collections")
load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "feature",
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
load(":utils.bzl", "check_args", "filter_none", "tee_filter")

OBJECT_EXTENSIONS_UNIX = ["o"]

# On Windows "lib" is directly linked like an object.
OBJECT_EXTENSIONS_WINDOWS = ["obj", "lib"]

def toolchain_import_configs(import_libs, object_extensions):
    """Convert cc_toolchain_import targets to configs for features.

    This feature purposefully ignores the (dynamic|static)_runtimes
    as those need to be propagated to the cc_toolchain target.

    Args:
        import_libs: A list of labels to cc_toolchain_import targets.
        object_extensions: File extensions of objects files.

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
        lambda f: f.extension in object_extensions,
    )
    static_linked_objects, static_mode_libs = tee_filter(
        static_mode_libs,
        lambda f: f.extension in object_extensions,
    )
    lib_search_paths = collections.uniq([
        f.dirname
        for f in dynamic_mode_libs + static_mode_libs
    ] + depset(transitive = [
        lib[CcToolchainImportInfo].lib_search_paths
        for lib in import_libs
    ], order = "topological").to_list())
    dynamic_lib_filenames = collections.uniq([
        f.basename
        for f in dynamic_mode_libs
    ])
    static_lib_filenames = collections.uniq([
        f.basename
        for f in static_mode_libs
    ])
    so_linked_objects = depset(transitive = [
        lib[CcToolchainImportInfo].so_linked_objects
        for lib in import_libs
    ]).to_list()

    return struct(
        include_paths = include_paths,
        framework_paths = framework_paths,
        dynamic_linked_objects = dynamic_linked_objects,
        static_linked_objects = static_linked_objects,
        lib_search_paths = lib_search_paths,
        dynamic_lib_filenames = dynamic_lib_filenames,
        static_lib_filenames = static_lib_filenames,
        so_linked_objects = so_linked_objects,
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

def get_b_prefix_feature(file):
    return feature(
        name = "b_prefix",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = C_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS + LINK_ACTIONS,
                flag_groups = [
                    flag_group(flags = ["-B", file.path] if file else []),
                ],
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
