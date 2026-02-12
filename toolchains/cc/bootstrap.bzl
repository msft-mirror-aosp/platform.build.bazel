"""Bootstraping binary macros, where bootstraping settings are set to true with transitions."""

load("@rules_cc//cc:defs.bzl", "cc_binary")
load("@with_cfg.bzl", "with_cfg")

cc_bootstrap_binary, _cc_bootstrap_binary_internal = with_cfg(
    cc_binary,
).set(
    Label("//toolchains/cc:bootstrap"),
    True,
).extend(
    "features",
    ["-thin_lto"],
).build()
