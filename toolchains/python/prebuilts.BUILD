package(default_visibility = ["@//build/bazel/toolchains/python:__subpackages__"])

filegroup(
    name = "linux_x86_files",
    srcs = glob(
        ["linux-x86/**"],
        exclude = ["**/* *"],
    ),
)

filegroup(
    name = "linux_x86_interpreter",
    srcs = ["linux-x86/bin/python3"],
)
