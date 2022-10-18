"""Emulator cc_toolchain configuration rule"""

load(":utils.bzl", "flatten")
load(
    ":features.bzl",
    "legacy_features_begin",
    "legacy_features_end",
    "no_implicit_libs_feature",
    "toolchain_compile_flags_feature",
    "toolchain_cxx_flags_feature",
    "toolchain_feature_flags",
    "toolchain_import_feature",
    "toolchain_link_flags_feature",
)
load(":actions.bzl", "create_action_tool_configs")
load(":cc_toolchain_import.bzl", "CcToolchainImportInfo")
load("@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl", "feature")

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
    return [
        _CcToolsInfo(
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
        ),
        DefaultInfo(files = depset(direct = ctx.files.tool_files)),
    ]

cc_tools = rule(
    implementation = _cc_tools_impl,
    attrs = {
        "tool_files": attr.label_list(
            doc = "All files needed to run tool binaries.",
            allow_files = True,
            mandatory = True,
        ),
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
    provides = [_CcToolsInfo, DefaultInfo],
)

def _toolchain_features(ctx):
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
    if ctx.attr.toolchain_imports:
        toolchain_features.append(
            toolchain_import_feature(ctx.attr.toolchain_imports),
        )
    return toolchain_features

def _toolchain_files(ctx):
    toolchain_import_files = [
        lib[DefaultInfo].files
        for lib in ctx.attr.toolchain_imports
    ]
    tool_files = [ctx.attr.cc_tools[DefaultInfo].files]
    return depset(transitive = toolchain_import_files + tool_files)

def _cc_toolchain_config_impl(ctx):
    no_builtin_legacy_features = feature(
        name = "no_legacy_features",
        enabled = True,
    )
    return [
        cc_common.create_cc_toolchain_config_info(
            ctx = ctx,
            toolchain_identifier = ctx.attr.identifier,
            features = flatten([
                no_builtin_legacy_features,
                no_implicit_libs_feature(),
                legacy_features_begin(),
                toolchain_feature_flags(),
                _toolchain_features(ctx),
                legacy_features_end(),
            ]),
            action_configs = create_action_tool_configs(ctx.attr.cc_tools[_CcToolsInfo]),
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
        ),
        DefaultInfo(
            files = _toolchain_files(ctx),
        ),
    ]

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
            providers = [_CcToolsInfo, DefaultInfo],
        ),
        "toolchain_imports": attr.label_list(
            doc = "A list of cc_toolchain_import targets.",
            providers = [CcToolchainImportInfo, DefaultInfo],
            default = [],
        ),
        "sysroot": attr.label(
            doc = "The sysroot directory.",
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
    provides = [CcToolchainConfigInfo, DefaultInfo],
)
