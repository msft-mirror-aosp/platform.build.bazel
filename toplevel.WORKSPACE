load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load(
    "//build/bazel/rules:repository.bzl",
    "json2bzl_repository",
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
    sha256 = "be04b635c7be4604be1ef20542e9870af3c49778ce841ee2d92fcb42f9d9516a",
    strip_prefix = "rules_python-0.35.0",
    url = "https://github.com/bazelbuild/rules_python/releases/download/0.35.0/rules_python-0.35.0.tar.gz",
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
    integrity = "sha256-3QBrdyIdWeTRQSB8DnrfEbH7YNFEC4/KA7+SVheTKmA=",
    patch_args = ["-p1"],
    patches = ["//build/bazel/toolchains/rust:fix-generated-file-with-sibling-layout.patch"],
    urls = ["https://github.com/bazelbuild/rules_rust/releases/download/0.49.3/rules_rust-v0.49.3.tar.gz"],
)

load("@rules_rust//rust:repositories.bzl", "rules_rust_dependencies")

rules_rust_dependencies()

new_local_repository(
    name = "boringssl",
    build_file = "//external/boringssl/src:BUILD.bazel",
    path = "external/boringssl/src",
    repo_mapping = {"@googletest": "@com_google_googletest"},
)

local_repository(
    name = "com_github_cares_cares",
    path = "external/cares",
)

local_repository(
    name = "perfetto",
    path = "external/perfetto",
)

local_repository(
    name = "perfetto_cfg",
    path = "build/bazel/perfetto_overrides",
)

local_repository(
    name = "rnnoise",
    path = "external/rnnoise",
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
    name = "pffft",
    path = "external/pffft",
)

local_repository(
    name = "pcre2",
    path = "external/pcre2",
)

local_repository(
    name = "libvpx",
    path = "external/libvpx",
)

new_local_repository(
    name = "nasm",
    build_file = "//external/nasm:BUILD",
    path = "external/nasm",
)

local_repository(
    name = "libjpeg_turbo",
    path = "external/libjpeg-turbo",
)

local_repository(
    name = "libyuv",
    path = "external/libyuv",
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
    name = "tink_cc",
    path = "external/tink",
)

load("@tink_cc//:tink_cc_deps.bzl", "tink_cc_deps")

tink_cc_deps()

load("@tink_cc//:tink_cc_deps_init.bzl", "tink_cc_deps_init")

tink_cc_deps_init()

local_repository(
    name = "com_github_google_flatbuffers",
    path = "external/flatbuffers",
)

local_repository(
    name = "webrtc",
    path = "external/webrtc",
)

http_archive(
    name = "wycheproof",
    sha256 = "eb1d558071acf1aa6d677d7f1cabec2328d1cf8381496c17185bd92b52ce7545",
    strip_prefix = "wycheproof-d8ed1ba95ac4c551db67f410c06131c3bc00a97c",
    url = "https://github.com/google/wycheproof/archive/d8ed1ba95ac4c551db67f410c06131c3bc00a97c.zip",
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
        "//build/bazel/toolchains:tool_versions.json": "TOOL_VERSIONS",
    },
    output_file = "defs.bzl",
)

load("@toolchain_defs//:defs.bzl", "TOOL_VERSIONS")

# Repositories that provide the clang compilers
new_local_repository(
    name = "clang_linux_x64",
    build_file = "//build/bazel/toolchains/cc/linux_clang:clang.BUILD",
    path = "prebuilts/clang/host/linux-x86/{}".format(TOOL_VERSIONS["clang"]),
)

new_local_repository(
    name = "clang_mac_all",
    build_file = "//build/bazel/toolchains/cc/mac_clang:clang.BUILD",
    path = "prebuilts/clang/host/darwin-x86/{}".format(TOOL_VERSIONS["clang"]),
)

new_local_repository(
    name = "clang_win_x64",
    build_file = "//build/bazel/toolchains/cc/windows_clang:clang.BUILD",
    path = "prebuilts/clang/host/windows-x86/{}".format(TOOL_VERSIONS["clang"]),
)

# Repository that provides include / libs from GCC
new_local_repository(
    name = "gcc_lib",
    build_file = "//build/bazel/toolchains/cc/linux_clang:gcc_lib.BUILD",
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

new_local_repository(
    name = "mingw64",
    build_file = "//build/bazel/toolchains/cc/windows_clang:mingw64.BUILD",
    path = "prebuilts/gcc/linux-x86/host/x86_64-w64-mingw32-4.8",
)

register_toolchains(
    "//build/bazel/toolchains/cc/linux_clang:x64_toolchain",
    "//build/bazel/toolchains/cc/mac_clang:x64_toolchain",
    "//build/bazel/toolchains/cc/mac_clang:arm64_toolchain",
    "//build/bazel/toolchains/cc/windows_clang:x64_toolchain",
    "//build/bazel/toolchains/cc/windows_clang:resource_compiler_x64",
)

# Repository that provides Python 3
new_local_repository(
    name = "python",
    build_file = "//build/bazel/toolchains/python:prebuilts.BUILD",
    path = "prebuilts/python",
)

register_toolchains(
    "@python//:linux_x86_toolchain",
    "@python//:windows_x86_toolchain",
    "@python//:mac_all_toolchain",
)

new_local_repository(
    name = "rust_mac",
    build_file = "//build/bazel/toolchains/rust:mac.BUILD",
    path = "prebuilts/rust/darwin-x86/{}".format(TOOL_VERSIONS["rust"]),
)

new_local_repository(
    name = "rust_linux",
    build_file = "//build/bazel/toolchains/rust:linux.BUILD",
    path = "prebuilts/rust/linux-x86/{}".format(TOOL_VERSIONS["rust"]),
)

new_local_repository(
    name = "rust_windows",
    build_file = "//build/bazel/toolchains/rust:windows.BUILD",
    path = "prebuilts/rust/windows-x86/{}".format(TOOL_VERSIONS["rust"]),
)

register_toolchains(
    "@rust_mac//:mac_arm64_toolchain",
    "@rust_mac//:mac_x64_toolchain",
    "@rust_linux//:linux_x64_toolchain",
    "@rust_windows//:windows_x64_toolchain",
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

local_repository(
    name = "com_github_grpc_grpc",
    path = "external/grpc",
)

local_repository(
    name = "utf8_range",
    path = "external/protobuf/third_party/utf8_range",
)

load("@com_github_grpc_grpc//bazel:grpc_deps.bzl", "grpc_deps")

grpc_deps()

load("@com_github_grpc_grpc//bazel:grpc_extra_deps.bzl", "grpc_extra_deps")

grpc_extra_deps()