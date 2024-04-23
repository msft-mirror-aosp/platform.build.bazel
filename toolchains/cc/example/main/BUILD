load("//build/bazel/rules:windows_resources.bzl", "windows_resources")

cc_library(
    name = "hello-greet",
    srcs = ["hello-greet.cc"],
    hdrs = ["hello-greet.h"],
)

cc_binary(
    name = "hello-world",
    srcs = ["hello-world.cc"],
    deps = [
        ":hello-greet",
        "//build/bazel/toolchains/cc/example/lib:hello-time",
    ] + select({
        "@platforms//os:windows": [":resources"],
        "//conditions:default": [],
    }),
)

windows_resources(
    name = "resources",
    rc_files = [
        "hello-world.rc",
    ],
)

cc_test(
    name = "hello-world_test",
    srcs = ["hello-world.cc"],
    deps = [
        ":hello-greet",
        "//build/bazel/toolchains/cc/example/lib:hello-time",
    ],
)
