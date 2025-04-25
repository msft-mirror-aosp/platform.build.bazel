"""dSYM support for macOS binaries."""

load("@//build/bazel/toolchains/cc:actions.bzl", "PACKAGE_DEBUG_SYMBOLS_ACTION_NAME")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

CPP_LINK_MNEMONIC = "CppLink"

AppleDsymInfo = provider(
    doc = "Metadata for generated Apple debug symbol (dSYM) bundle.",
    fields = ["executable_file", "dsym_bundle"],
)

def _gen_dsym_aspect_impl(target, ctx):
    """Creates a dSYM bundle using dsymutil.

    It tries to look for a CppLink action in the current target, and searches upstream targets
    if none is found. This propagation allows binary post-processing (e.g. signing) to happen
    and we still can find the target where linking was done.
    """
    executable_file = target.files_to_run.executable or target.files.to_list()[0]  # type: File
    if hasattr(target.output_groups, "dsym_folder"):
        return [AppleDsymInfo(
            executable_file = executable_file,
            dsym_bundle = target.output_groups.dsym_folder.to_list()[0],
        )]
    linker_action = [action for action in target.actions if action.mnemonic == CPP_LINK_MNEMONIC]  # type: list[Action]
    if not linker_action:
        return _dsym_from_upstream(ctx = ctx, attr_name = "srcs")
    if len(linker_action) > 1:
        fail("This aspect cannot be attached to target", target.label, "because it has multiple", CPP_LINK_MNEMONIC, "actions.")
    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    if not cc_common.is_enabled(
        feature_configuration = feature_configuration,
        feature_name = "generate_dsym_file",
    ):
        return []
    if not cc_common.action_is_enabled(
        feature_configuration = feature_configuration,
        action_name = PACKAGE_DEBUG_SYMBOLS_ACTION_NAME,
    ):
        fail(
            "--apple_generate_dsym is turned on but no action config is enabled for",
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
    linker_inputs = linker_action[0].inputs
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
    return [
        AppleDsymInfo(executable_file = executable_file, dsym_bundle = output),
        OutputGroupInfo(dsym_folder = depset([output])),
    ]

def _dsym_from_upstream(ctx, attr_name):
    if not hasattr(ctx.rule.attr, attr_name):
        return []
    targets = getattr(ctx.rule.attr, attr_name)  # type: list[Target]
    if type(targets) != "list":
        targets = [targets]
    for t in targets:
        if AppleDsymInfo in t:
            return [
                t[AppleDsymInfo],
                OutputGroupInfo(dsym_folder = depset([t[AppleDsymInfo].dsym_bundle])),
            ]
    return []

gen_dsym_aspect = aspect(
    doc = "Create dSYM bundle for macOS cc binaries.",
    implementation = _gen_dsym_aspect_impl,
    # Propagate the aspect along srcs attribute. This mostly accomondates genrule for binary post-processing.
    attr_aspects = ["srcs"],
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
    apply_to_generating_rules = True,
)
