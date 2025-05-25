"""TODO remove """

load("@rules_rust//rust:defs.bzl", _rust_proc_macro = "rust_proc_macro")

def rust_proc_macro(**kwargs):
    _rust_proc_macro(**kwargs)
