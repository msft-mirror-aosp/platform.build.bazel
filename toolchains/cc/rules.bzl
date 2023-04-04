"""Platform and tool independent toolchain rules."""

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
