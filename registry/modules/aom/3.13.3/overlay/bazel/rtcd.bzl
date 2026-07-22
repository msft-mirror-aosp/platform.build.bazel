"""RTCD (Runtime CPU Detection) header generation rule for libaom.

Runs a Python 3 clone of rtcd.pl to produce RTCD dispatch headers.
"""

def _rtcd_gen_impl(ctx):
    out = ctx.actions.declare_file(ctx.attr.out)

    args = ctx.actions.args()
    args.add(ctx.attr.arch, format = "--arch=%s")
    args.add(ctx.attr.sym, format = "--sym=%s")
    args.add_all(ctx.attr.disable, format_each = "--disable-%s")
    args.add(ctx.file.config, format = "--config=%s")
    args.add(out, format = "--out=%s")
    args.add(ctx.file.defs)

    ctx.actions.run(
        executable = ctx.executable._rtcd_tool,
        inputs = [ctx.file.config, ctx.file.defs],
        outputs = [out],
        arguments = [args],
        mnemonic = "AomRtcdGen",
    )
    return [DefaultInfo(files = depset([out]))]

rtcd_gen = rule(
    implementation = _rtcd_gen_impl,
    doc = "Generate RTCD dispatch header from a perlasm definition file.",
    attrs = {
        "arch": attr.string(
            mandatory = True,
            doc = "Target architecture for RTCD (x86_64 or arm64).",
        ),
        "config": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "The aom_config.h file.",
        ),
        "defs": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "The RTCD definitions file (.pl).",
        ),
        "disable": attr.string_list(
            default = [],
            doc = "List of extensions to disable (e.g. ['sve', 'sve2']).",
        ),
        "out": attr.string(
            mandatory = True,
            doc = "Output header file path.",
        ),
        "sym": attr.string(
            mandatory = True,
            doc = "Symbol prefix for the RTCD functions (e.g. aom_dsp_rtcd).",
        ),
        "_rtcd_tool": attr.label(
            default = Label("//:rtcd"),
            executable = True,
            cfg = "exec",
            doc = "The Python rtcd compiler binary.",
        ),
    },
)
