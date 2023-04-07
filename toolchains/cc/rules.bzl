"""Platform and tool independent toolchain rules."""

load(":actions.bzl", "create_action_configs")

CcToolInfo = provider(
    "A provider that specifies metadata for a tool.",
    fields = {
        "tool": "A File object to be used as the tool executable.",
        "applied_actions": "Cc actions where this tool applies.",
        "with_features": "Feature names that need to be enabled to select this tool.",
        "with_no_features": "Feature names that need to be disabled to select this tool.",
    },
)

def _cc_tool_impl(ctx):
    runfiles = ctx.runfiles(
        files = [ctx.executable.tool] + ctx.files.runfiles,
    )
    runfiles = runfiles.merge(ctx.attr.tool[DefaultInfo].default_runfiles)
    return [
        CcToolInfo(
            tool = ctx.executable.tool,
            applied_actions = ctx.attr.applied_actions,
            with_features = ctx.features,
            with_no_features = ctx.disabled_features,
        ),
        DefaultInfo(
            files = depset([ctx.executable.tool]),
            runfiles = runfiles,
        ),
    ]

cc_tool = rule(
    implementation = _cc_tool_impl,
    attrs = {
        "tool": attr.label(
            doc = "The tool target.",
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            mandatory = True,
        ),
        "runfiles": attr.label_list(
            doc = "Other files needed to run the tool, in addition to what provided by the tool target.",
            allow_files = True,
        ),
        "applied_actions": attr.string_list(
            doc = "A list of cc action names where the tool applies.",
            mandatory = True,
            allow_empty = False,
        ),
    },
    provides = [CcToolInfo, DefaultInfo],
)

CcToolchainImportInfo = provider(
    doc = "Provides info about the imported toolchain library.",
    fields = {
        "include_paths": "Include directories for this library.",
        "dynamic_mode_libraries": "Libraries to be linked in dynamic linking mode.",
        "dynamic_runtimes": "Libraries used as the dynamic runtime library of cc_toolchain.",
        "static_mode_libraries": "Libraries to be linked in static linking mode.",
        "static_runtimes": "Libraries used as the static runtime library of cc_toolchain.",
        "so_linked_objects": "Directly linked objects to shared libraries.",
    },
)

def _cc_toolchain_import_impl(ctx):
    if ctx.files.hdrs and not ctx.files.include_paths:
        fail(ctx.label, ": 'include_paths' is mandatory when 'hdrs' is not empty.")
    include_paths = [p.path for p in ctx.files.include_paths]

    dep_include_paths = [
        dep[CcToolchainImportInfo].include_paths
        for dep in ctx.attr.deps
    ]
    dep_shared_libs = [
        dep[CcToolchainImportInfo].dynamic_mode_libraries
        for dep in ctx.attr.deps
    ]
    dep_static_libs = [
        dep[CcToolchainImportInfo].static_mode_libraries
        for dep in ctx.attr.deps
    ]
    dep_dynamic_runtimes = [
        dep[CcToolchainImportInfo].dynamic_runtimes
        for dep in ctx.attr.deps
    ]
    dep_static_runtimes = [
        dep[CcToolchainImportInfo].static_runtimes
        for dep in ctx.attr.deps
    ]
    dep_so_linked_objs = [
        dep[CcToolchainImportInfo].so_linked_objects
        for dep in ctx.attr.deps
    ]

    if ctx.attr.is_runtime_lib:
        static_libs, dynamic_libs = [], []
        static_runtimes = ctx.files.static_mode_libs
        dynamic_runtimes = ctx.files.dynamic_mode_libs
    else:
        static_runtimes, dynamic_runtimes = [], []
        static_libs = ctx.files.static_mode_libs
        dynamic_libs = ctx.files.dynamic_mode_libs

    return [
        CcToolchainImportInfo(
            include_paths = depset(
                direct = include_paths,
                transitive = dep_include_paths,
                order = "topological",
            ),
            dynamic_mode_libraries = depset(
                direct = dynamic_libs,
                transitive = dep_shared_libs,
                order = "topological",
            ),
            static_mode_libraries = depset(
                direct = static_libs,
                transitive = dep_static_libs,
                order = "topological",
            ),
            dynamic_runtimes = depset(
                direct = dynamic_runtimes,
                transitive = dep_dynamic_runtimes,
                order = "topological",
            ),
            static_runtimes = depset(
                direct = static_runtimes,
                transitive = dep_static_runtimes,
                order = "topological",
            ),
            so_linked_objects = depset(
                direct = ctx.files.so_linked_objects,
                transitive = dep_so_linked_objs,
            ),
        ),
        DefaultInfo(
            files = depset(
                direct = ctx.files.hdrs +
                         ctx.files.dynamic_mode_libs +
                         ctx.files.static_mode_libs +
                         ctx.files.support_files +
                         ctx.files.so_linked_objects,
                transitive = [dep[DefaultInfo].files for dep in ctx.attr.deps],
            ),
        ),
    ]

cc_toolchain_import = rule(
    implementation = _cc_toolchain_import_impl,
    doc = "A rule that works like cc_import but at the toolchain level.",
    attrs = {
        "hdrs": attr.label_list(
            default = [],
            doc = "Header files for this library.",
            allow_files = True,
        ),
        "include_paths": attr.label_list(
            default = [],
            doc = "Include paths to search for headers. Mandatory if hdrs is set.",
            allow_files = True,
        ),
        "dynamic_mode_libs": attr.label_list(
            default = [],
            doc = "Libraries to be linked in dynamic linking mode." +
                  "\n" +
                  "When is_runtime_lib is True, libraries will be passed to cc_toolchain " +
                  "as 'dynamic_runtime_lib', which places them in the runpath.",
            allow_files = True,
        ),
        "static_mode_libs": attr.label_list(
            default = [],
            doc = "Libraries to be linked in static linking mode." +
                  "\n" +
                  "When is_runtime_lib is True, libraries will be passed to cc_toolchain " +
                  "as 'static_runtime_lib' (requires all libs to be static).",
            allow_files = True,
        ),
        "support_files": attr.label_list(
            default = [],
            doc = "Files needed but not linked.",
            allow_files = True,
        ),
        "is_runtime_lib": attr.bool(
            doc = "If true, the libraries are consumed by the appropriate *_runtime_lib attribute for cc_toolchain.\n" +
                  "\n" +
                  "Used in conjunction with dynamic_mode_libs and " +
                  "static_mode_libs to pass values to cc_toolchain via the " +
                  "cc_toolchain_(dynamic|static)_runtime rules.\n" +
                  "\n" +
                  "Set this to False if the libs will come from the host " +
                  "(e.g. glibc), and to True otherwise.",
        ),
        "so_linked_objects": attr.label_list(
            default = [],
            doc = "Objects to be directly linked to shared libraries.",
            allow_files = True,
        ),
        "deps": attr.label_list(
            default = [],
            doc = "Other cc_toolchain_import rules to depend on.",
            providers = [CcToolchainImportInfo, DefaultInfo],
        ),
    },
    provides = [CcToolchainImportInfo, DefaultInfo],
)

def _cc_toolchain_runtime_impl(ctx):
    if ctx.attr._use_dynamic:
        get_field = lambda x: x.dynamic_runtimes
    else:
        get_field = lambda x: x.static_runtimes

    lib_files = depset(
        transitive = [get_field(lib[CcToolchainImportInfo]) for lib in ctx.attr.libs],
        order = "topological",
    )
    return DefaultInfo(
        files = lib_files,
    )

cc_toolchain_dynamic_runtime = rule(
    implementation = _cc_toolchain_runtime_impl,
    doc = "Creates the runtime library for dynamically linked libraries, matching the dynamic_runtime_lib attribute of a cc_toolchain.",
    attrs = {
        "libs": attr.label_list(
            doc = "The cc_toolchain_import rules to consume.",
            providers = [CcToolchainImportInfo],
            mandatory = True,
        ),
        "_use_dynamic": attr.bool(default = True),
    },
)

cc_toolchain_static_runtime = rule(
    implementation = _cc_toolchain_runtime_impl,
    doc = "Creates the runtime library for statically linked libraries, matching the static_runtime_lib attribute of a cc_toolchain.",
    attrs = {
        "libs": attr.label_list(
            doc = "The cc_toolchain_import rules to consume.",
            providers = [CcToolchainImportInfo],
            mandatory = True,
        ),
        "_use_dynamic": attr.bool(default = False),
    },
)

CcFeatureConfigInfo = provider(
    doc = "Provides info about the configured features.",
    fields = {
        "features": "A list of ordered FeatureInfo",
    },
)

def _toolchain_files(ctx):
    toolchain_import_files = [
        lib[DefaultInfo].files
        for lib in ctx.attr.toolchain_imports
    ]
    tool_files = [tool[DefaultInfo].files for tool in ctx.attr.cc_tools]
    tool_runfiles = [
        tool[DefaultInfo].default_runfiles.files
        for tool in ctx.attr.cc_tools
    ]
    return depset(
        transitive = toolchain_import_files + tool_files + tool_runfiles,
    )

def _cc_toolchain_config_impl(ctx):
    return [
        cc_common.create_cc_toolchain_config_info(
            ctx = ctx,
            toolchain_identifier = ctx.attr.identifier,
            features = ctx.attr.cc_features[CcFeatureConfigInfo].features,
            action_configs = create_action_configs(
                [tool[CcToolInfo] for tool in ctx.attr.cc_tools],
            ),
            builtin_sysroot = ctx.file.sysroot.path if ctx.file.sysroot else None,
            target_cpu = ctx.attr.target_cpu,
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
        "cc_tools": attr.label_list(
            doc = "A list of targets that provides CcToolInfo.",
            mandatory = True,
            allow_empty = False,
            providers = [CcToolInfo, DefaultInfo],
        ),
        "cc_features": attr.label(
            doc = "A target that provides CcFeatureConfigInfo.",
            mandatory = True,
            providers = [CcFeatureConfigInfo],
        ),
        "target_cpu": attr.string(
            doc = "Target CPU architecture. This only affects the directory name of execution and output trees.",
            mandatory = True,
        ),
        "toolchain_imports": attr.label_list(
            doc = "A list of cc_toolchain_import targets.",
            providers = [DefaultInfo],
            default = [],
        ),
        "sysroot": attr.label(
            doc = "The sysroot directory.",
            allow_single_file = True,
        ),
    },
    provides = [CcToolchainConfigInfo, DefaultInfo],
)
