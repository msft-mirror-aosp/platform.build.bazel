"""Emulator cc_toolchain configuration rule"""

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
