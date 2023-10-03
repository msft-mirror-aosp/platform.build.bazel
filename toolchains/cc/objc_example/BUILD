objc_library(
    name = "hello",
    srcs = [
        "defs/defs.h",
        "hello.m",
    ],
    copts = ["-iquote $(execpath defs)"],
    data = ["defs"],
)
