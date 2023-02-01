"""android_library rule."""

load("@rules_kotlin//kotlin:common.bzl", _kt_common = "common")
load("@rules_kotlin//kotlin:compiler_opt.bzl", "merge_kotlincopts")
load("@rules_kotlin//kotlin:jvm_compile.bzl", "kt_jvm_compile")
load("@rules_kotlin//kotlin:traverse_exports.bzl", _kt_traverse_exports = "kt_traverse_exports")
load("@rules_kotlin//toolchains/kotlin_jvm:kt_jvm_toolchains.bzl", _kt_jvm_toolchains = "kt_jvm_toolchains")
load("@rules_android//rules:acls.bzl", _acls = "acls")
load(
    "@rules_android//rules:attrs.bzl",
    _attrs = "attrs",
)
load(
    "@rules_android//rules:common.bzl",
    _common = "common",
)
load(
    "@rules_android//rules:java.bzl",
    _java = "java",
)
load(
    "@rules_android//rules:processing_pipeline.bzl",
    "ProviderInfo",
    "processing_pipeline",
)
load("@rules_android//rules:utils.bzl", "get_android_toolchain", "utils")
load(
    "@rules_android//rules/android_library:attrs.bzl",
    _BASE_ATTRS = "ATTRS",
)
load(
    "@rules_android//rules/android_library:impl.bzl",
    "finalize",
    _BASE_PROCESSORS = "PROCESSORS",
)
load(
    "@rules_android//rules/android_library:rule.bzl",
    _attrs_metadata = "attrs_metadata",
    _make_rule = "make_rule",
)
load("@rules_android//rules:providers.bzl", "AndroidLintRulesInfo")
load("@rules_kotlin//kotlin:compiler_opt.bzl", "kotlincopts_attrs")

KT_COMPILER_ATTRS = _attrs.add(
    kotlincopts_attrs(),
    dict(
        common_srcs = attr.label_list(
            allow_files = [".kt"],
            doc = """The list of common multi-platform source files that are processed to create
                 the target.""",
        ),
        coverage_srcs = attr.label_list(allow_files = True),
        # Magic attribute name for DexArchiveAspect
        _toolchain = attr.label(
            default = Label(
                "@rules_kotlin//toolchains/kotlin_jvm:kt_jvm_toolchain_impl",
            ),
        ),
    ),
)

ATTRS = _attrs.add(
    _attrs.replace(
        _BASE_ATTRS,
        deps = attr.label_list(
            allow_rules = [
                "aar_import",
                "android_library",
                "cc_library",
                "java_import",
                "java_library",
                "java_lite_proto_library",
            ],
            aspects = [
                _kt_traverse_exports.aspect,
            ],
            providers = [
                [CcInfo],
                [JavaInfo],
            ],
            doc = (
                "The list of other libraries to link against. Permitted library types " +
                "are: `android_library`, `java_library` with `android` constraint and " +
                "`cc_library` wrapping or producing `.so` native libraries for the " +
                "Android target platform."
            ),
        ),
        exported_plugins = attr.label_list(
            allow_rules = [
                "java_plugin",
            ],
            cfg = "exec",
        ),
        exports = attr.label_list(
            allow_rules = [
                "aar_import",
                "android_library",
                "cc_library",
                "java_import",
                "java_library",
                "java_lite_proto_library",
            ],
            aspects = [
                _kt_traverse_exports.aspect,
            ],
            providers = [
                [CcInfo],
                [JavaInfo],
            ],
            doc = (
                "The closure of all rules reached via `exports` attributes are considered " +
                "direct dependencies of any rule that directly depends on the target with " +
                "`exports`. The `exports` are not direct deps of the rule they belong to."
            ),
        ),
        exports_manifest = _attrs.tristate.create(
            default = _attrs.tristate.no,
            doc = (
                "Whether to export manifest entries to `android_binary` targets that " +
                "depend on this target. `uses-permissions` attributes are never exported."
            ),
        ),
        plugins = attr.label_list(
            providers = [
                [JavaPluginInfo],
            ],
            cfg = "exec",
            doc = (
                "Java compiler plugins to run at compile-time. Every `java_plugin` " +
                "specified in the plugins attribute will be run whenever this target " +
                "is built. Resources generated by the plugin will be included in " +
                "the result jar of the target."
            ),
        ),
        srcs = attr.label_list(
            allow_files = [
                ".kt",
                ".java",
                ".srcjar",
            ],
        ),
    ),
    KT_COMPILER_ATTRS,
)

def _validations_processor(ctx, **unused_sub_ctxs):
    utils.check_for_failures(ctx.label, ctx.attr.deps, ctx.attr.exports)

def _process_jvm(ctx, java_package, exceptions_ctx, resources_ctx, idl_ctx, db_ctx, **unused_sub_ctxs):
    # Filter out disallowed sources.
    srcs = ctx.files.srcs + idl_ctx.idl_java_srcs + db_ctx.java_srcs

    # kt_jvm_compile expects deps that only carry CcInfo in runtime_deps
    deps = [dep for dep in ctx.attr.deps if JavaInfo in dep] + idl_ctx.idl_deps
    runtime_deps = [dep for dep in ctx.attr.deps if JavaInfo not in dep]

    jvm_ctx = kt_jvm_compile(
        ctx,
        ctx.outputs.lib_jar,
        # ctx.outputs.lib_src_jar,  # Implicitly determines file.
        srcs = srcs,
        common_srcs = ctx.files.common_srcs,
        coverage_srcs = ctx.files.coverage_srcs,
        deps = deps,
        plugins = ctx.attr.plugins + db_ctx.java_plugins,
        exports = ctx.attr.exports,
        # As the JavaInfo constructor does not support attaching
        # exported_plugins, for the purposes of propagation, the plugin is
        # wrapped in a java_library.exported_plugins target and attached with
        # export to this rule.
        exported_plugins = ctx.attr.exported_plugins,
        runtime_deps = runtime_deps,
        r_java = resources_ctx.r_java,
        javacopts = ctx.attr.javacopts + db_ctx.javac_opts,
        kotlincopts = merge_kotlincopts(ctx),
        neverlink = ctx.attr.neverlink,
        testonly = ctx.attr.testonly,
        android_lint_plugins = [],
        android_lint_rules_jars = depset(),
        manifest = getattr(ctx.file, "manifest", None),
        merged_manifest = resources_ctx.merged_manifest,
        resource_files = ctx.files.resource_files,
        kt_toolchain = _kt_jvm_toolchains.get(ctx),
        java_toolchain = _common.get_java_toolchain(ctx),
        disable_lint_checks = [],
        rule_family = _kt_common.RULE_FAMILY.ANDROID_LIBRARY,
        annotation_processor_additional_outputs = (
            db_ctx.java_annotation_processor_additional_outputs
        ),
        annotation_processor_additional_inputs = (
            db_ctx.java_annotation_processor_additional_inputs
        ),
    )

    java_info = jvm_ctx.java_info

    return ProviderInfo(
        name = "jvm_ctx",
        value = struct(
            java_info = java_info,
            providers = [java_info],
        ),
    )

def _process_coverage(ctx, **_unused_ctx):
    return ProviderInfo(
        name = "coverage_ctx",
        value = struct(
            providers = [
                coverage_common.instrumented_files_info(
                    ctx,
                    source_attributes = ["srcs", "coverage_srcs"],
                    dependency_attributes = ["assets", "deps", "exports"],
                ),
            ],
        ),
    )

PROCESSORS = processing_pipeline.prepend(
    processing_pipeline.replace(
        _BASE_PROCESSORS,
        JvmProcessor = _process_jvm,
        CoverageProcessor = _process_coverage,
    ),
    ValidationsProcessor = _validations_processor,
)

_PROCESSING_PIPELINE = processing_pipeline.make_processing_pipeline(
    processors = PROCESSORS,
    finalize = finalize,
)

def _impl(ctx):
    java_package = _java.resolve_package_from_label(ctx.label, ctx.attr.custom_package)
    return processing_pipeline.run(ctx, java_package, _PROCESSING_PIPELINE)

android_library = _make_rule(
    attrs = ATTRS,
    implementation = _impl,
    additional_toolchains = [_kt_jvm_toolchains.type],
)

def android_library_macro(**attrs):
    """AOSP android_library rule.

    Args:
      **attrs: Rule attributes
    """
    android_library(**_attrs_metadata(attrs))
