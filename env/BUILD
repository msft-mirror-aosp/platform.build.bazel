load("@rules_python//python:defs.bzl", "py_library", "py_test")

py_library(
    name = "setup_dev_env",
    testonly = 1,
    srcs = ["setup_dev_env.py"],
)

py_test(
    name = "setup_dev_env_test",
    srcs = ["setup_dev_env_test.py"],
    deps = [
        ":setup_dev_env",
        "@absl-py//absl/testing:absltest",
    ],
)
