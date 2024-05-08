load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load(
    "//build/bazel/rules:repository.bzl",
    "json2bzl_repository",
    "selective_local_repository",
)

# Skylib provides common utilities for writing bazel rules and functions.
# For docs see https://github.com/bazelbuild/bazel-skylib/blob/main/README.md
http_archive(
    name = "bazel_skylib",
    sha256 = "9f38886a40548c6e96c106b752f242130ee11aaa068a56ba7e56f4511f33e4f2",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.6.1/bazel-skylib-1.6.1.tar.gz",
        "https://github.com/bazelbuild/bazel-skylib/releases/download/1.6.1/bazel-skylib-1.6.1.tar.gz",
    ],
)

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

# Python rules (https://github.com/bazelbuild/rules_python)
http_archive(
    name = "rules_python",
    sha256 = "c68bdc4fbec25de5b5493b8819cfc877c4ea299c0dcb15c244c5a00208cde311",
    strip_prefix = "rules_python-0.31.0",
    url = "https://github.com/bazelbuild/rules_python/releases/download/0.31.0/rules_python-0.31.0.tar.gz",
)

load("@rules_python//python:repositories.bzl", "py_repositories")

py_repositories()

# Package rules (https://github.com/bazelbuild/rules_pkg)
http_archive(
    name = "rules_pkg",
    sha256 = "d250924a2ecc5176808fc4c25d5cf5e9e79e6346d79d5ab1c493e289e722d1d0",
    urls = [
        "https://github.com/bazelbuild/rules_pkg/releases/download/0.10.1/rules_pkg-0.10.1.tar.gz",
    ],
)

load("@rules_pkg//:deps.bzl", "rules_pkg_dependencies")

rules_pkg_dependencies()

http_archive(
    name = "with_cfg.bzl",
    sha256 = "06a2b1b56a58c471ab40d8af166c4d51f0982e1c6bc46375b805915b3fc0658e",
    strip_prefix = "with_cfg.bzl-0.2.4",
    url = "https://github.com/fmeum/with_cfg.bzl/releases/download/v0.2.4/with_cfg.bzl-v0.2.4.tar.gz",
)

http_archive(
    name = "rules_rust",
    integrity = "sha256-JLN47ZcAbx9wEr5Jiib4HduZATGLiDgK7oUi/fvotzU=",
    patch_args = ["-p1"],
    patches = ["//build/bazel/toolchains/rust:rules_rust_sibling_layout.patch"],
    urls = ["https://github.com/bazelbuild/rules_rust/releases/download/0.42.1/rules_rust-v0.42.1.tar.gz"],
)

load("@rules_rust//rust:repositories.bzl", "rules_rust_dependencies", "rust_register_toolchains")

rules_rust_dependencies()

rust_register_toolchains(versions = ["1.73.0"])

new_local_repository(
    name = "boringssl",
    build_file = "//external/boringssl:BUILD",
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
    path = "external/abseil-cpp",
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
    path = "external/regex-re2",
)

local_repository(
    name = "meson",
    path = "external/meson",
)

local_repository(
    name = "pcre2",
    path = "external/pcre2",
)

local_repository(
    name = "glib",
    path = "external/glib",
)

local_repository(
    name = "pixman",
    path = "external/pixman",
)

local_repository(
    name = "zlib",
    path = "external/zlib",
)

local_repository(
    name = "upb",
    path = "external/grpc/third_party/upb",
)

local_repository(
    name = "com_github_google_flatbuffers",
    path = "external/flatbuffers",
)

# CC toolchains
load(
    "//build/bazel/toolchains/cc:repository_rules.bzl",
    "macos_sdk_repository",
    "msvc_tools_repository",
    "windows_sdk_repository",
)

json2bzl_repository(
    name = "toolchain_defs",
    config_mapping = {
        "//build/bazel/rules:toolchains.json": "TOOL_VERSIONS",
    },
    output_file = "defs.bzl",
)

# Repository that provides the clang compilers
selective_local_repository(
    name = "clang",
    build_file = "//build/bazel/toolchains/cc:clang.BUILD",
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
    build_file = "//build/bazel/toolchains/cc/linux_clang:gcc_lib.BUILD",
    # Ignore pre-existing BUILD files so we can use our own BUILD file without
    # touching the ones added by go/roboleaf.
    ignore_filenames = [
        "BUILD",
        "BUILD.bazel",
    ],
    path = "prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8",
)

macos_sdk_repository(
    name = "macos_sdk",
    build_file = "//build/bazel/toolchains/cc/mac_clang:sdk.BUILD",
)

msvc_tools_repository(
    name = "vctools",
    build_file = "//build/bazel/toolchains/cc/windows_clang:vctools.BUILD",
)

windows_sdk_repository(
    name = "windows_sdk",
    build_file_template = "//build/bazel/toolchains/cc/windows_clang:sdk.BUILD.tpl",
    sdk_path = "C:\\Program Files (x86)\\Windows Kits\\10",
)

# Repository that provides Python 3
new_local_repository(
    name = "python",
    build_file = "//build/bazel/toolchains/python:prebuilts.BUILD",
    path = "prebuilts/python",
)

register_toolchains(
    "//build/bazel/toolchains/cc/linux_clang:x64_toolchain",
    "//build/bazel/toolchains/cc/mac_clang:x64_toolchain",
    "//build/bazel/toolchains/cc/mac_clang:arm64_toolchain",
    "//build/bazel/toolchains/cc/windows_clang:x64_toolchain",
    "//build/bazel/toolchains/cc/windows_clang:resource_compiler_x64",
)

register_toolchains(
    "//build/bazel/toolchains/python:linux_x86_toolchain",
)

# Rust crates, note that these follow the AOSP style of naming, where every crate
# is basically @..crate..
# Once the rust team has an automated bazel generation tool, we will no longer need these.
# See b/335734830 for details
[
    new_local_repository(
        name = create,
        build_file = "//hardware/generic/goldfish/third_party/rust/crates:BUILD.{}".format(create),
        path = "external/rust/crates/{}".format(create),
    )
    for create in [
        "bitflags",
        "byteorder",
        "cfg-if",
        "libc",
        "log",
        "memoffset",
        "nix",
        "once_cell",
        "proc-macro2",
        "quote",
        "remain",
        "syn",
        "thiserror-impl",
        "thiserror",
        "unicode-ident",
        "zerocopy-derive",
        "zerocopy",
    ]
]

new_local_repository(
    name = "winapi",
    build_file = "//hardware/generic/goldfish/third_party/rust/crates:BUILD.winapi",
    path = "hardware/generic/goldfish/third_party/rust/crates/winapi",
)

new_local_repository(
    name = "winapi-x86_64-pc-windows-gnu",
    build_file = "//hardware/generic/goldfish/third_party/rust/crates:BUILD.winapi-x86_64-pc-windows-gnu",
    path = "hardware/generic/goldfish/third_party/rust/crates/winapi-x86_64-pc-windows-gnu",
)
