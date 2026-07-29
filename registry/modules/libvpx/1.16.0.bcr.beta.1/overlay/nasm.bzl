"""Build rules for converting ADS ARM assembly source files to GAS syntax.

This module provides rules and macros to compile ARM assembly (.asm) files
written in ADS/RVDS format to GNU Assembler (.S) format, resolving header
includes for Bazel's output directory layout.
"""

load("@bazel_skylib//rules:expand_template.bzl", "expand_template")
load("@rules_cc//cc:cc_library.bzl", "cc_library")

def _sanitize(src):
    """Sanitizes source path strings to generate valid Bazel target names."""
    return src.replace("/", "_").replace(".", "_").replace("-", "_")

def _parent_prefix(src):
    """Returns directory traversal prefix to address relative header file inclusion."""
    depth = len(src.split("/")) - 1
    return "../" * depth

def _libvpx_arm_asm_source_impl(ctx):
    """Implementation of the _libvpx_arm_asm_source rule.

    Runs the ads2gas.py Python script to rewrite ADS ARM assembly syntax into
    compatible GAS format (.S) files.
    """
    args = ctx.actions.args()
    args.add(ctx.outputs.out, format = "--out=%s")
    args.add(ctx.file.src, format = "--src=%s")
    args.add(ctx.attr.config_include, format = "--config-include=%s")

    for script_arg in ctx.attr.script_args:
        if script_arg == "-thumb":
            args.add("--thumb")
        elif script_arg == "-noelf":
            args.add("--noelf")

    ctx.actions.run(
        executable = ctx.executable._ads2gas_tool,
        inputs = [
            ctx.file.src,
        ],
        outputs = [ctx.outputs.out],
        arguments = [args],
        mnemonic = "LibvpxArmAsmSource",
    )

    return [DefaultInfo(files = depset([ctx.outputs.out]))]

_libvpx_arm_asm_source = rule(
    implementation = _libvpx_arm_asm_source_impl,
    doc = "Rewrites a single ADS ARM assembly source file to GAS syntax.",
    attrs = {
        "config_include": attr.string(
            mandatory = True,
            doc = "The relative prefix to format the vpx_config.asm header include.",
        ),
        "out": attr.output(
            mandatory = True,
            doc = "The target GAS output file (.S).",
        ),
        "script_args": attr.string_list(
            doc = "Optional script parameters (e.g. -thumb or -noelf).",
        ),
        "src": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "The source ADS ARM assembly (.asm) file.",
        ),
        "_ads2gas_tool": attr.label(
            default = Label("@libvpx//:ads2gas"),
            executable = True,
            cfg = "exec",
            doc = "The Python ads2gas compiler binary.",
        ),
    },
)

def libvpx_arm_asm_library(name, srcs, config_target, target_compatible_with = None):
    """Macro compiling multiple ADS assembly sources and bundling them into a cc_library.

    Args:
        name: The target library name.
        srcs: A list of ADS assembly (.asm) source files to compile.
        config_target: The target vpx_config.asm configuration template.
        target_compatible_with: Constraint list of compatible platform targets.
    """
    if target_compatible_with == None:
        target_compatible_with = []

    config_name = "{}_config".format(name)
    config_out = "arm_asm/{}/vpx_config.asm".format(name)
    expand_template(
        name = config_name,
        substitutions = {},
        out = config_out,
        template = config_target,
        target_compatible_with = target_compatible_with,
    )

    converted_srcs = []
    for src in srcs:
        rule_name = "{}_{}".format(name, _sanitize(src))
        out_name = "arm_asm/{}/{}.S".format(name, src)
        converted_srcs.append(out_name)
        _libvpx_arm_asm_source(
            name = rule_name,
            config_include = _parent_prefix(src),
            out = out_name,
            script_args = [],
            src = src,
            target_compatible_with = target_compatible_with,
        )

    cc_library(
        name = name,
        srcs = converted_srcs,
        hdrs = [config_out],
        copts = [
            "-Wa,-I$(GENDIR)/arm_asm/{}".format(name),
            "-mfpu=neon",
        ],
        target_compatible_with = target_compatible_with,
        visibility = ["//visibility:private"],
    )
