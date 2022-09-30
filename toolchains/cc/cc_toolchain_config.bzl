"""Emulator cc_toolchain configuration rule"""

load(
    ":utils.bzl",
    "flatten",
)
load(
    ":features.bzl",
    "legacy_features_begin",
    "legacy_features_end",
    "toolchain_binary_search_path_feature",
    "toolchain_compile_flags_feature",
    "toolchain_cxx_flags_feature",
    "toolchain_feature_flags",
    "toolchain_gcc_toolchain_feature",
    "toolchain_lib_search_paths_feature",
    "toolchain_link_flags_feature",
)
load(
    ":actions.bzl",
    "create_action_tool_configs",
)
load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "feature",
)

_CcToolsInfo = provider(
    "A provider that specifies various ToolInfo for a cc toolchain.",
    fields = [
        "ar",
        "ar_features",
        "cxx",
        "cxx_features",
        "gcc",
        "gcc_features",
        "ld",
        "ld_features",
        "strip",
        "strip_features",
    ],
)

def _cc_tools_impl(ctx):
    return _CcToolsInfo(
        gcc = ctx.executable.gcc,
        gcc_features = ctx.attr.gcc_features,
        ld = ctx.executable.ld,
        ld_features = ctx.attr.ld_features,
        ar = ctx.executable.ar,
        ar_features = ctx.attr.ar_features,
        cxx = ctx.executable.cxx,
        cxx_features = ctx.attr.cxx_features,
        strip = ctx.executable.strip,
        strip_features = ctx.attr.strip_features,
    )

cc_tools = rule(
    implementation = _cc_tools_impl,
    attrs = {
        "ar": attr.label(
            doc = "Path to the archiver.",
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            mandatory = True,
        ),
        "ar_features": attr.string_list(
            doc = "A list of applicable optional features.",
            default = [],
        ),
        "cxx": attr.label(
            doc = "Path to the c++ compiler.",
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            mandatory = True,
        ),
        "cxx_features": attr.string_list(
            doc = "A list of applicable optional features.",
            default = [],
        ),
        "gcc": attr.label(
            doc = "Path to the c compiler.",
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            mandatory = True,
        ),
        "gcc_features": attr.string_list(
            doc = "A list of applicable optional features.",
            default = [],
        ),
        "ld": attr.label(
            doc = "Path to the linker.",
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            mandatory = True,
        ),
        "ld_features": attr.string_list(
            doc = "A list of applicable optional features.",
            default = [],
        ),
        "strip": attr.label(
            doc = "Path to the strip utility.",
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            mandatory = True,
        ),
        "strip_features": attr.string_list(
            doc = "A list of applicable optional features.",
            default = [],
        ),
    },
)

def _toolchain_features(ctx):
    library_search_paths = [f.path for f in ctx.files.library_search_paths]

    toolchain_features = []
    if ctx.attr.compile_flags:
        toolchain_features.append(
            toolchain_compile_flags_feature(ctx.attr.compile_flags),
        )
    if ctx.attr.link_flags:
        toolchain_features.append(
            toolchain_link_flags_feature(ctx.attr.link_flags),
        )
    if ctx.attr.cxx_flags:
        toolchain_features.append(
            toolchain_cxx_flags_feature(ctx.attr.cxx_flags),
        )
    if library_search_paths:
        toolchain_features.append(
            toolchain_lib_search_paths_feature(library_search_paths),
        )
    if ctx.file.gcc_toolchain:
        toolchain_features.append(
            toolchain_gcc_toolchain_feature(ctx.file.gcc_toolchain.path),
        )
    if ctx.file.binary_search_path:
        toolchain_features.append(
            toolchain_binary_search_path_feature(
                ctx.file.binary_search_path.path,
            ),
        )
    return toolchain_features

def _cc_toolchain_config_impl(ctx):
    include_paths = [f.path for f in ctx.files.include_paths]

    no_builtin_legacy_features = feature(
        name = "no_legacy_features",
        enabled = True,
    )
    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        toolchain_identifier = ctx.attr.identifier,
        features = flatten([
            no_builtin_legacy_features,
            legacy_features_begin(),
            toolchain_feature_flags(),
            _toolchain_features(ctx),
            legacy_features_end(),
        ]),
        action_configs = create_action_tool_configs(ctx.attr.cc_tools[_CcToolsInfo]),
        cxx_builtin_include_directories = include_paths,
        builtin_sysroot = ctx.file.sysroot.path if ctx.file.sysroot else None,
        # The target_cpu is required for toolchain selection when using
        # "cc_toolchain_suite", but unused if done thru "register_toolchain"
        target_cpu = "__toolchain_target_cpu__",
        # The attributes below are required by the constructor, but don't
        # affect actions at all.
        target_system_name = "__toolchain_target_system_name__",
        compiler = "__toolchain_compiler__",
        target_libc = "__toolchain_target_libc__",
        abi_version = "__toolchain_abi_version__",
        abi_libc_version = "__toolchain_abi_libc_version__",
    )

cc_toolchain_config = rule(
    implementation = _cc_toolchain_config_impl,
    attrs = {
        "identifier": attr.string(
            doc = "Unique toolchain identifier.",
            mandatory = True,
        ),
        "cc_tools": attr.label(
            doc = "A target that provides _CcToolsInfo.",
            mandatory = True,
            providers = [_CcToolsInfo],
        ),
        "include_paths": attr.label_list(
            doc = "Built-in include directories",
            allow_files = True,
            default = [],
        ),
        "library_search_paths": attr.label_list(
            doc = "Library search directories (e.g. -L), " +
                  "added to all cc_toolchains using this config.",
            allow_files = True,
            default = [],
        ),
        "sysroot": attr.label(
            doc = "The sysroot directory.",
            allow_single_file = True,
        ),
        "gcc_toolchain": attr.label(
            doc = "Directory containing the gcc toolchain.",
            allow_single_file = True,
        ),
        "binary_search_path": attr.label(
            doc = "Directory containing the gcc toolchain.",
            allow_single_file = True,
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
    },
    provides = [CcToolchainConfigInfo],
)
