load("@rules_python//python:defs.bzl", "py_library")
load("//build/bazel/rules/gathering:write_package_metadata.bzl", "write_package_metadata")

package(
    default_package_metadata = [
        "//build/bazel/licenses:Android-Apache-2.0",
    ],
)

py_library(
    name = "example_lib",
    srcs = ["example.py"],
    data = [
        "//prebuilts/r8:d8",
        "@intellij//:intellij-sdk",
    ],
)

write_package_metadata(
    name = "example-metadata",
    deps = [
        ":example_lib",
    ],
)
