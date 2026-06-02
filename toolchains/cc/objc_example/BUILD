load("//third_party/bazel_rules/rules_cc/cc:objc_library.bzl", "objc_library")

objc_library(
    name = "hello",
    srcs = [
        "defs/defs.h",
        "hello.m",
    ],
    copts = ["-iquote $(execpath defs)"],
    data = ["defs"],
)
