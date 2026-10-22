load("@rules_python//python:defs.bzl", "py_library", "py_test")

py_library(
    name = "credhelper_lib",
    srcs = ["credhelper.py"],
    visibility = ["//visibility:public"],
)

py_test(
    name = "credhelper_test",
    srcs = ["credhelper_test.py"],
    deps = [
        ":credhelper_lib",
        "@absl-py//absl/testing:absltest",
    ],
)
