"""Build rules for generating run-time CPU detection (RTCD) headers for libvpx.

This module provides rules and macros to compile RTCD definition files (.pl)
into C headers (.h) specifying optimized CPU feature function pointers.
"""

def _libvpx_rtcd_header_impl(ctx):
    """Implementation of the _libvpx_rtcd_header rule.

    Runs the rtcd.py Python script to parse a definition file (e.g. vp8_rtcd_defs.pl)
    and produce the C header output.
    """
    args = ctx.actions.args()
    args.add(ctx.attr.arch, format = "--arch=%s")
    args.add(ctx.attr.sym, format = "--sym=%s")
    args.add_all(ctx.attr.extra_args)
    args.add(ctx.file.config_file, format = "--config=%s")
    args.add(ctx.outputs.out, format = "--out=%s")
    args.add(ctx.file.defs_file)

    ctx.actions.run(
        executable = ctx.executable._rtcd_tool,
        inputs = [
            ctx.file.config_file,
            ctx.file.defs_file,
        ],
        outputs = [ctx.outputs.out],
        arguments = [args],
        mnemonic = "LibvpxRtcdHeader",
    )

    return [DefaultInfo(files = depset([ctx.outputs.out]))]

_libvpx_rtcd_header = rule(
    implementation = _libvpx_rtcd_header_impl,
    doc = "Generates a single RTCD header file from a definition file.",
    attrs = {
        "arch": attr.string(
            mandatory = True,
            doc = "Target architecture (e.g., x86, x86_64, arm64).",
        ),
        "config_file": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "The generated vpx_config.h/rtcd configuration file.",
        ),
        "defs_file": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "The definition file containing the RTCD DSL (e.g., vp8_rtcd_defs.pl).",
        ),
        "extra_args": attr.string_list(
            doc = "Extra disable/require target CPU features parameters.",
        ),
        "out": attr.output(
            mandatory = True,
            doc = "The output generated C header file.",
        ),
        "sym": attr.string(
            mandatory = True,
            doc = "The symbol name suffix for the RTCD initialization function.",
        ),
        "_rtcd_tool": attr.label(
            default = Label("@libvpx//:rtcd"),
            executable = True,
            cfg = "exec",
            doc = "The Python rtcd compiler binary.",
        ),
    },
)

def libvpx_rtcd_headers(name, arch, config_file, out_dir, disable_avx512 = False, disable_neon_i8mm = False, disable_sve = False, disable_sve2 = False):
    """Macro that generates all standard RTCD headers for a target architecture.

    Args:
        name: The name of the generated filegroup target containing all headers.
        arch: Target CPU architecture.
        config_file: The configuration settings target file.
        out_dir: Destination output directory path relative to package.
        disable_avx512: Disable AVX-512 features.
        disable_neon_i8mm: Disable Neon i8mm features.
        disable_sve: Disable ARM SVE features.
        disable_sve2: Disable ARM SVE2 features.
    """
    extra_args = []
    if disable_avx512:
        extra_args.append("--disable-avx512")
    if disable_neon_i8mm:
        extra_args.append("--disable-neon_i8mm")
    if disable_sve:
        extra_args.append("--disable-sve")
    if disable_sve2:
        extra_args.append("--disable-sve2")

    defs = [
        ("vp8_rtcd", "@libvpx//:vp8/common/rtcd_defs.pl"),
        ("vp9_rtcd", "@libvpx//:vp9/common/vp9_rtcd_defs.pl"),
        ("vpx_dsp_rtcd", "@libvpx//:vpx_dsp/vpx_dsp_rtcd_defs.pl"),
        ("vpx_scale_rtcd", "@libvpx//:vpx_scale/vpx_scale_rtcd.pl"),
    ]

    generated = []
    for sym, defs_file in defs:
        out = "{}/{}.h".format(out_dir, sym)
        target_name = "{}_{}".format(name, sym)
        _libvpx_rtcd_header(
            name = target_name,
            arch = arch,
            config_file = config_file,
            defs_file = defs_file,
            extra_args = extra_args,
            out = out,
            sym = sym,
        )
        generated.append(target_name)

    native.filegroup(
        name = name,
        srcs = generated,
    )
