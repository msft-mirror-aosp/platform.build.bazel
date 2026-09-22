load("@rules_cc//cc:defs.bzl", _cc_binary = "cc_binary", _cc_library = "cc_library")

raw_cc_library = _cc_library
llvm_targets = [
    "X86",
]

def cc_library(**kwargs):
    if kwargs.get("srcs"):
        kwargs["alwayslink"] = True
        kwargs["cxxopts"] = kwargs.get("cxxopts", []) + ["-std=c++17", "-fno-rtti"]
    _cc_library(**kwargs)

def cc_binary(**kwargs):
    kwargs["cxxopts"] = kwargs.get("cxxopts", []) + ["-std=c++17", "-fno-rtti"]
    _cc_binary(**kwargs)
