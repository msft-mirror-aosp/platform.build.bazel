load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//build/bazel/rules:repository.bzl", "selective_local_repository")

# Skylib provides common utilities for writing bazel rules and functions.
# For docs see https://github.com/bazelbuild/bazel-skylib/blob/main/README.md
http_archive(
    name = "bazel_skylib",
    sha256 = "f7be3474d42aae265405a592bb7da8e171919d74c16f082a5457840f06054728",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.2.1/bazel-skylib-1.2.1.tar.gz",
        "https://github.com/bazelbuild/bazel-skylib/releases/download/1.2.1/bazel-skylib-1.2.1.tar.gz",
    ],
)

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

# Repository that provides the clang compilers
selective_local_repository(
    name = "clang",
    build_file = "build/bazel/toolchains/cc/clang.BUILD",
    # Ignore pre-existing BUILD files so we can use our own BUILD file without
    # touching the ones added by go/roboleaf.
    ignore_filenames = [
        "BUILD",
        "BUILD.bazel",
    ],
    path = "prebuilts/clang/host",
)

# Repository that provides include / libs from GCC
selective_local_repository(
    name = "gcc_lib",
    build_file = "build/bazel/toolchains/cc/gcc_lib.BUILD",
    # Ignore pre-existing BUILD files so we can use our own BUILD file without
    # touching the ones added by go/roboleaf.
    ignore_filenames = [
        "BUILD",
        "BUILD.bazel",
    ],
    path = "prebuilts/gcc/linux-x86/host",
)

new_local_repository(
    name = "boringssl",
    path = "external/boringssl",
    build_file = "external/boringssl/BUILD",
)

# CC toolchains
register_toolchains(
    "//build/bazel/toolchains/cc:linux_clang_x64_toolchain",
)
