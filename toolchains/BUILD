load("@rules_python//python:defs.bzl", "py_test")

py_test(
    name = "tool_versions_test",
    srcs = ["tool_versions_test.py"],
    data = [
        ":tool_versions.json",
        ":toolchain.MODULE.bazel",
    ],
    deps = ["@rules_python//python/runfiles"],
)
