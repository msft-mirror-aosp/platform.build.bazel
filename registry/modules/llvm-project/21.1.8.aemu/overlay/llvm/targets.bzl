"""Wrapper rules and configuration transition helpers for LLVM targets."""

load("@rules_cc//cc:defs.bzl", _cc_binary = "cc_binary", _cc_library = "cc_library")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@with_cfg.bzl", "with_cfg")

raw_cc_library = _cc_library
llvm_targets = [
    "AArch64",
    "X86",
]

def _cc_forwarder_impl(ctx):
    actual = ctx.attr.actual
    providers = [
        actual[CcInfo],
        DefaultInfo(
            files = actual[DefaultInfo].files,
            runfiles = actual[DefaultInfo].default_runfiles,
        ),
    ]
    if OutputGroupInfo in actual:
        providers.append(actual[OutputGroupInfo])
    return providers

_cc_forwarder = rule(
    implementation = _cc_forwarder_impl,
    attrs = {
        "actual": attr.label(
            mandatory = True,
            providers = [CcInfo],
        ),
    },
)

cc_opt_alias, _cc_opt_alias_internal = with_cfg(_cc_forwarder).set("compilation_mode", "opt").build()

def cc_library(**kwargs):
    if kwargs.get("srcs"):
        kwargs["alwayslink"] = select({
            "@bazel_tools//src/conditions:darwin": False,
            "//conditions:default": True,
        })
        kwargs["cxxopts"] = kwargs.get("cxxopts", []) + ["-std=c++17", "-fno-rtti"]
    _cc_library(**kwargs)

def cc_binary(**kwargs):
    kwargs["cxxopts"] = kwargs.get("cxxopts", []) + ["-std=c++17", "-fno-rtti"]
    _cc_binary(**kwargs)
