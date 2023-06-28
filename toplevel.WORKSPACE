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

# Python rules (https://github.com/bazelbuild/rules_python)
http_archive(
    name = "rules_python",
    sha256 = "36362b4d54fcb17342f9071e4c38d63ce83e2e57d7d5599ebdde4670b9760664",
    strip_prefix = "rules_python-0.18.0",
    url = "https://github.com/bazelbuild/rules_python/releases/download/0.18.0/rules_python-0.18.0.tar.gz",
)

load("@rules_python//python:repositories.bzl", "py_repositories")

py_repositories()

# Package rules (https://github.com/bazelbuild/rules_pkg)
http_archive(
    name = "rules_pkg",
    sha256 = "8c20f74bca25d2d442b327ae26768c02cf3c99e93fad0381f32be9aab1967675",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_pkg/releases/download/0.8.1/rules_pkg-0.8.1.tar.gz",
        "https://github.com/bazelbuild/rules_pkg/releases/download/0.8.1/rules_pkg-0.8.1.tar.gz",
    ],
)

load("@rules_pkg//:deps.bzl", "rules_pkg_dependencies")

rules_pkg_dependencies()

new_local_repository(
    name = "boringssl",
    build_file = "external/boringssl/BUILD",
    path = "external/boringssl",
)

local_repository(
    name = "com_github_cares_cares",
    path = "external/cares",
)

local_repository(
    name = "com_github_google_benchmark",
    path = "external/google-benchmark",
)

local_repository(
    name = "com_google_absl",
    path = "external/webrtc/third_party/abseil-cpp",
)

local_repository(
    name = "com_google_googletest",
    path = "external/googletest",
)

local_repository(
    name = "com_google_protobuf",
    path = "external/protobuf",
)

local_repository(
    name = "com_googlesource_code_re2",
    path = "external/qemu/android/third_party/re2",
)

local_repository(
    name = "zlib",
    path = "external/zlib",
)

local_repository(
    name = "upb",
    path = "external/grpc/third_party/upb",
)

http_archive(
    name = "com_google_googleapis",
    sha256 = "38701e513aff81c89f0f727e925bf04ac4883913d03a60cdebb2c2a5f10beb40",
    strip_prefix = "googleapis-86fa44cc5ee2136e87c312f153113d4dd8e9c4de",
    urls = [
        "https://storage.googleapis.com/grpc-bazel-mirror/github.com/googleapis/googleapis/archive/86fa44cc5ee2136e87c312f153113d4dd8e9c4de.tar.gz",
        "https://github.com/googleapis/googleapis/archive/86fa44cc5ee2136e87c312f153113d4dd8e9c4de.tar.gz",
    ],
)

local_repository(
    name = "com_github_grpc_grpc",
    path = "external/grpc",
)

load("@com_github_grpc_grpc//bazel:grpc_deps.bzl", "grpc_deps", "grpc_test_only_deps")

grpc_deps()

grpc_test_only_deps()

load("@com_github_grpc_grpc//bazel:grpc_extra_deps.bzl", "grpc_extra_deps")

grpc_extra_deps()

# CC toolchains
load(
    "//build/bazel/toolchains/cc:repository_rules.bzl",
    "macos_sdk_repository",
    "msvc_tools_repository",
    "windows_sdk_repository",
)

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
    build_file = "build/bazel/toolchains/cc/linux_clang/gcc_lib.BUILD",
    # Ignore pre-existing BUILD files so we can use our own BUILD file without
    # touching the ones added by go/roboleaf.
    ignore_filenames = [
        "BUILD",
        "BUILD.bazel",
    ],
    path = "prebuilts/gcc/linux-x86/host",
)

macos_sdk_repository(
    name = "macos_sdk",
    build_file = "build/bazel/toolchains/cc/mac_clang/sdk.BUILD",
)

msvc_tools_repository(
    name = "vctools",
    build_file = "build/bazel/toolchains/cc/windows_clang/vctools.BUILD",
)

windows_sdk_repository(
    name = "windows_sdk",
    build_file_template = "build\\bazel\\toolchains\\cc\\windows_clang\\sdk.BUILD.tpl",
    sdk_path = "C:\\Program Files (x86)\\Windows Kits\\10",
)

register_toolchains(
    "//build/bazel/toolchains/cc/linux_clang:x64_toolchain",
    "//build/bazel/toolchains/cc/mac_clang:x64_toolchain",
    "//build/bazel/toolchains/cc/mac_clang:arm64_toolchain",
    "//build/bazel/toolchains/cc/windows_clang:x64_toolchain",
)
