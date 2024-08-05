package(default_visibility = ["@//build/bazel/toolchains/python:__subpackages__"])

filegroup(
    name = "linux_x86_files",
    srcs = glob(
        [
            "linux-x86/bin/**",
            "linux-x86/lib/**",
        ],
        exclude = [
            "**/* *",
            "linux-x86/lib/pkgconfig/**",
            "**/*.pyc",
        ],
    ),
)

filegroup(
    name = "linux_x86_interpreter",
    srcs = ["linux-x86/bin/python3"],
)
