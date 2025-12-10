"""Debug symbol support.

This module defines aspects and providers used to generate and collect debug symbols
(dSYM, GNU .debug, PDB) based on the value of the `//rules/native:generate_debug_package`
build setting.

The main aspects are:
-   `gen_dsym_aspect`: Generates Apple dSYM bundles for macOS targets. Activated when
    `//rules/native:generate_debug_package` is "dsym".
-   `gen_gnu_debug_aspect`: Generates GNU-style .debug files for ELF binaries. Activated when
    `//rules/native:generate_debug_package` is "gnu". It depends on `collect_fission_package_aspect`
    to find .dwp files.
-   `collect_pdb_aspect`: Collects Windows PDB files. Activated when
    `//rules/native:generate_debug_package` is "pdb".

Helper aspects:
-   `collect_fission_package_aspect`: Collects `FissionPackageInfo` (containing .dwp files)
    transitivelly from dependencies. Used by `gen_gnu_debug_aspect`.
"""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:debug_package_info.bzl", "DebugPackageInfo")
load("//toolchains/cc:actions.bzl", "PACKAGE_DEBUG_SYMBOLS_ACTION_NAME")

_CPP_LINK_MNEMONIC = "CppLink"
_OBJCOPY_TOOLCHAIN_TYPE = "//toolchains/cc:objcopy_toolchain_type"

_DEBUG_PACKAGE_SWITCH_FLAG = "//rules/native:generate_debug_package"

def _provider_init_default(defaults):
    return lambda **kwargs: dicts.add(defaults, **kwargs)

FissionPackageInfo, _new_fission_package_info = provider(
    doc = "Metadata for generated fission (dwp) packages.",
    fields = ["executable_file", "dwp_file", "original_executable_file"],
    init = _provider_init_default({
        "original_executable_file": None,
    }),
)

FissionPackageSetInfo = provider(
    doc = "A depset of FissionPackageInfo.",
    fields = ["fission_package"],
)

AppleDsymInfo, _new_apple_dsym_info = provider(
    doc = "Metadata for generated Apple debug symbol (dSYM) bundle.",
    fields = ["executable_file", "dsym_bundle", "original_executable_file"],
    init = _provider_init_default({
        "original_executable_file": None,
    }),
)

GnuDebugInfo, _new_gnu_debug_info = provider(
    doc = "Metadata for GNU debug files from ELF binaries.",
    fields = ["executable_file", "debug_file", "dwp_file", "original_executable_file"],
    init = _provider_init_default({
        "dwp_file": None,
        "original_executable_file": None,
    }),
)

WindowsPdbInfo, _new_windows_pdb_info = provider(
    doc = "Metadata for generated Windows PDB files.",
    fields = ["executable_file", "pdb_file", "original_executable_file"],
    init = _provider_init_default({
        "original_executable_file": None,
    }),
)

DebugSymbolsSetInfo, _new_debug_symbols_set_info = provider(
    doc = "A collection of debug symbols.",
    fields = {
        "dsym": "A depset of AppleDsymInfo.",
        "gnu": "A depset of GnuDebugInfo.",
        "pdb": "A depset of WindowsPdbInfo.",
    },
    init = _provider_init_default({
        "dsym": None,
        "gnu": None,
        "pdb": None,
    }),
)

def _provider_from_upstream(ctx, attr_name, provider):
    if not hasattr(ctx.rule.attr, attr_name):
        return []
    targets = getattr(ctx.rule.attr, attr_name)  # type: list[Target]
    if type(targets) != "list":
        targets = [targets]
    transitive = []
    for t in targets:
        if provider in t:
            transitive.append(t[provider])
    return transitive

def _maybe_remap_to_new_binary(target, upstream, provider_remapper_fn):
    """When postprocessing a binary (single-in-single-out), remap debug symbol from the input to the output.

    Args:
        target: The current target.
        upstream: A list of depsets containing debug symbols from upstream.
        provider_remapper_fn: A function(upstream, executable) that takes an upstream provider and an
          executable, and returns a new provider with the executable replacing the one in the provider.

    Returns:
        A list of depsets containing the remapped debug symbols, or the original upstream depsets if no
        remapping is possible.
    """
    if target.files_to_run.executable or len(target.files.to_list()) == 1:
        if len(upstream) == 1 and len(upstream[0].to_list()) == 1:
            executable_file = target.files_to_run.executable or target.files.to_list()[0]  # type: File
            upstream = [depset([
                provider_remapper_fn(upstream = upstream[0].to_list()[0], executable = executable_file),
            ])]
    return upstream

def _gen_dsym_aspect_impl(target, ctx):
    """Creates a dSYM bundle using dsymutil.

    It tries to look for a CppLink action in the current target, and searches upstream targets
    if none is found. This propagation allows binary post-processing (e.g. signing) to happen
    and we still can find the target where linking was done.
    """
    if ctx.attr._switch_flag[BuildSettingInfo].value != "dsym":
        return []

    if hasattr(target.output_groups, "dsym_folder"):
        executable_file = target.files_to_run.executable or target.files.to_list()[0]  # type: File
        return [DebugSymbolsSetInfo(
            dsym = depset([AppleDsymInfo(
                executable_file = executable_file,
                dsym_bundle = target.output_groups.dsym_folder.to_list()[0],
                original_executable_file = executable_file,
            )]),
        )]
    linker_actions = [action for action in target.actions if action.mnemonic == _CPP_LINK_MNEMONIC]  # type: list[Action]
    if not linker_actions:
        transitive = [
            t.dsym
            for t in _provider_from_upstream(ctx, "srcs", DebugSymbolsSetInfo)
            if t.dsym
        ]
        transitive = _maybe_remap_to_new_binary(target, transitive, lambda upstream, executable: AppleDsymInfo(
            executable_file = executable,
            dsym_bundle = upstream.dsym_bundle,
            original_executable_file = upstream.original_executable_file,
        ))
        if transitive:
            return [DebugSymbolsSetInfo(
                dsym = depset(transitive = transitive),
            )]
        return []

    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    if not cc_common.action_is_enabled(
        feature_configuration = feature_configuration,
        action_name = PACKAGE_DEBUG_SYMBOLS_ACTION_NAME,
    ):
        fail(
            _DEBUG_PACKAGE_SWITCH_FLAG,
            "is dsym but no action config is enabled for",
            PACKAGE_DEBUG_SYMBOLS_ACTION_NAME,
        )

    dsymutil = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = PACKAGE_DEBUG_SYMBOLS_ACTION_NAME,
    )
    cc_variables = cc_common.empty_variables()
    dsymutil_env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = PACKAGE_DEBUG_SYMBOLS_ACTION_NAME,
        variables = cc_variables,
    )
    dsymutil_flags = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = PACKAGE_DEBUG_SYMBOLS_ACTION_NAME,
        variables = cc_variables,
    )
    dsym = []
    for linker_action in linker_actions:
        linker_inputs = linker_action.inputs
        executable_file = linker_action.outputs.to_list()[0]
        dsym_bundle_name = executable_file.basename + ".dSYM"
        output = ctx.actions.declare_directory(dsym_bundle_name, sibling = executable_file)
        ctx.actions.run(
            mnemonic = "AppleDsymLink",
            progress_message = "Linking Apple dSYM " + output.short_path,
            outputs = [output],
            inputs = depset([executable_file], transitive = [linker_inputs]),
            executable = dsymutil,
            arguments = dsymutil_flags + [executable_file.path],
            env = dsymutil_env,
        )
        dsym.append(AppleDsymInfo(
            executable_file = executable_file,
            dsym_bundle = output,
            original_executable_file = executable_file,
        ))
    return [DebugSymbolsSetInfo(
        dsym = depset(dsym),
    )]

gen_dsym_aspect = aspect(
    doc = """Create dSYM bundle for macOS binaries.

    This aspect is applied to targets to generate dSYM bundles for Apple platforms.
    It is typically attached to top-level targets that need debug symbols,
    and it propagates through 'srcs' to find the linking actions.
    """,
    implementation = _gen_dsym_aspect_impl,
    attrs = {
        "_switch_flag": attr.label(default = _DEBUG_PACKAGE_SWITCH_FLAG),
    },
    # Propagate the aspect along srcs attribute. This mostly accomondates genrule / filegroup.
    attr_aspects = ["srcs"],
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
    apply_to_generating_rules = True,
)

def _collect_fission_package_aspect_impl(target, ctx):
    if DebugPackageInfo in target and target[DebugPackageInfo].dwp_file:
        debug_package = target[DebugPackageInfo]
        return [FissionPackageSetInfo(fission_package = depset([
            FissionPackageInfo(
                executable_file = debug_package.unstripped_file,
                dwp_file = debug_package.dwp_file,
                original_executable_file = debug_package.unstripped_file,
            ),
        ]))]
    transitive = [
        t.fission_package
        for t in _provider_from_upstream(ctx, "srcs", FissionPackageSetInfo)
        if t.fission_package
    ]
    transitive = _maybe_remap_to_new_binary(target, transitive, lambda upstream, executable: DebugPackageInfo(
        executable_file = executable,
        dwp_file = upstream.dwp_file,
        original_executable_file = upstream.original_executable_file,
    ))
    if transitive:
        return [FissionPackageSetInfo(
            fission_package = depset(transitive = transitive),
        )]
    return [FissionPackageSetInfo(fission_package = None)]

collect_fission_package_aspect = aspect(
    doc = """Collect DebugPackageInfo from upstream targets.

    This aspect is used to collect `DebugPackageInfo` providers, which contain
    information about .dwp files generated during linking. It propagates
    through 'srcs' to gather this information from dependencies.
    """,
    implementation = _collect_fission_package_aspect_impl,
    # Propagate the aspect along srcs attribute. This mostly accomondates genrule / filegroup.
    attr_aspects = ["srcs"],
    apply_to_generating_rules = True,
    provides = [FissionPackageSetInfo],
)

def is_elf_binary(file):
    """Checks whether the file is possibly an ELF binary.

    Args:
        file: The file to check.

    Returns:
        True if the file is possibly an ELF binary.
    """

    # type: (File) -> bool
    if not file.extension:
        return True
    if file.extension == "so":
        return True
    stem, extension = paths.split_extension(file.basename)
    if extension[1:].isdigit() and stem.endswith(".so"):
        # liba.so.1
        return True
    return False

def _gen_gnu_debug_aspect_impl(target, ctx):
    if ctx.attr._switch_flag[BuildSettingInfo].value != "gnu":
        return []

    toolchain = ctx.toolchains[_OBJCOPY_TOOLCHAIN_TYPE]
    if not toolchain:
        fail("Flag", _DEBUG_PACKAGE_SWITCH_FLAG, "is gnu, but no toolchain is available for toolchain type", _OBJCOPY_TOOLCHAIN_TYPE)
    objcopy = toolchain.tool
    if target.files_to_run.executable:
        binaries = [target.files_to_run.executable]
    else:
        binaries = [f for f in target.files.to_list() if is_elf_binary(f)]

    dwp_lookup = {}
    if FissionPackageSetInfo in target and target[FissionPackageSetInfo].fission_package:
        for fission_package in target[FissionPackageSetInfo].fission_package.to_list():
            dwp_lookup[fission_package.executable_file] = fission_package

    gnu = []
    empty_fission_package = FissionPackageInfo(dwp_file = None)
    for executable_file in binaries:
        debug_file_name = executable_file.basename + ".debug"
        output = ctx.actions.declare_file(debug_file_name, sibling = executable_file)
        ctx.actions.run(
            mnemonic = "GnuDebugInfo",
            progress_message = "Extracting Debug Info " + output.short_path,
            outputs = [output],
            inputs = [executable_file],
            executable = objcopy.executable,
            tools = objcopy.runfiles,
            arguments = objcopy.args + ["--only-keep-debug", executable_file.path, output.path],
            env = objcopy.env,
            toolchain = _OBJCOPY_TOOLCHAIN_TYPE,
        )
        gnu.append(GnuDebugInfo(
            executable_file = executable_file,
            debug_file = output,
            dwp_file = dwp_lookup.get(executable_file, empty_fission_package).dwp_file,
            original_executable_file = dwp_lookup.get(executable_file, empty_fission_package).original_executable_file,
        ))
    return [DebugSymbolsSetInfo(
        gnu = depset(gnu),
    )]

gen_gnu_debug_aspect = aspect(
    doc = """Create GNU debug file for ELF binaries.

    This aspect is applied to targets to generate GNU-style .debug files from ELF binaries.
    It is typically attached to top-level targets when GNU debug symbols are requested.
    It uses the `collect_fission_package_aspect` to find associated .dwp files.
    """,
    implementation = _gen_gnu_debug_aspect_impl,
    attrs = {
        "_switch_flag": attr.label(default = _DEBUG_PACKAGE_SWITCH_FLAG),
    },
    toolchains = [config_common.toolchain_type(
        _OBJCOPY_TOOLCHAIN_TYPE,
        mandatory = False,
    )],
    required_aspect_providers = [FissionPackageSetInfo],
    requires = [collect_fission_package_aspect],
)

def _collect_pdb_aspect_impl(target, ctx):
    if ctx.attr._switch_flag[BuildSettingInfo].value != "pdb":
        return []

    if OutputGroupInfo in target and hasattr(target[OutputGroupInfo], "pdb_file"):
        executable_file = target.files_to_run.executable or [
            f
            for f in target.files.to_list()
            if f.extension in ["exe", "dll"]
        ][0]  # type: File
        pdb_file = target[OutputGroupInfo].pdb_file.to_list()[0]
        return [DebugSymbolsSetInfo(
            pdb = depset([WindowsPdbInfo(
                executable_file = executable_file,
                pdb_file = pdb_file,
                original_executable_file = executable_file,
            )]),
        )]
    transitive = [
        t.pdb
        for t in _provider_from_upstream(ctx, "srcs", DebugSymbolsSetInfo)
        if t.pdb
    ]
    transitive = _maybe_remap_to_new_binary(target, transitive, lambda upstream, executable: WindowsPdbInfo(
        executable_file = executable,
        pdb_file = upstream.pdb_file,
        original_executable_file = upstream.original_executable_file,
    ))
    if transitive:
        return [DebugSymbolsSetInfo(
            pdb = depset(transitive = transitive),
        )]
    return []

collect_pdb_aspect = aspect(
    doc = """Collect pdb from upstream targets.

    This aspect is used to collect Windows PDB files. It looks for PDB outputs
    in the current target's `OutputGroupInfo` or propagates collected PDB info
    from upstream 'srcs'.
    """,
    implementation = _collect_pdb_aspect_impl,
    attrs = {
        "_switch_flag": attr.label(default = _DEBUG_PACKAGE_SWITCH_FLAG),
    },
    # Propagate the aspect along srcs attribute. This mostly accomondates genrule / filegroup.
    attr_aspects = ["srcs"],
    apply_to_generating_rules = True,
)
