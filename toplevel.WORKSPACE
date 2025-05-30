load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load(
    "//build/bazel/rules:repository.bzl",
    "json2bzl_repository",
)

local_repository(
    name = "com_github_cares_cares",
    path = "third_party/cares",
)

local_repository(
    name = "perfetto",
    path = "third_party/perfetto",
)

local_repository(
    name = "perfetto_cfg",
    path = "build/bazel/perfetto_overrides",
)

local_repository(
    name = "rnnoise",
    path = "third_party/rnnoise",
)

local_repository(
    name = "com_google_crashpad",
    path = "third_party/crashpad",
)

register_toolchains(
    "@com_google_crashpad//util:mig_toolchain",
)

local_repository(
    name = "meson",
    path = "third_party/meson",
)

local_repository(
    name = "pffft",
    path = "third_party/pffft",
)

local_repository(
    name = "libvpx",
    path = "third_party/libvpx",
)

new_local_repository(
    name = "nasm",
    build_file = "//third_party/nasm:BUILD",
    path = "third_party/nasm",
)

local_repository(
    name = "libjpeg_turbo",
    path = "third_party/libjpeg-turbo",
)

local_repository(
    name = "libyuv",
    path = "third_party/libyuv",
)

local_repository(
    name = "glib",
    path = "third_party/glib",
)

local_repository(
    name = "pixman",
    path = "third_party/pixman",
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
    "msvc_tools_repository",
    "windows_sdk_repository",
    "xcode_tools_repository",
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

xcode_tools_repository(
    name = "xcode_tools",
    build_file = "//build/bazel/toolchains/cc/mac_clang:xcode.BUILD",
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
    name = "rust_linux",
    build_file = "//build/bazel/toolchains/rust:linux.BUILD",
    path = "prebuilts/rust/linux-x86/{}".format(TOOL_VERSIONS["rust"]),
)

register_toolchains(
    "@rust_linux//:linux_x64_toolchain",
)

load(
    "//build/bazel/platforms:host_platform.bzl",
    "host_conditions",
    "host_platform_repository",
)

host_platform_repository(
    name = "host_platform",
    host = {
        host_conditions(
            arch = "x64",
            os = "linux",
        ): "//build/bazel/platforms:linux_x64",
        host_conditions(
            arch = "x64",
            os = "macos",
        ): "//build/bazel/platforms:macos_x64",
        host_conditions(
            arch = "arm64",
            os = "macos",
        ): "//build/bazel/platforms:macos_aarch64",
        host_conditions(
            arch = "x64",
            os = "windows",
        ): "//build/bazel/platforms:windows_x64",
    },
)

local_repository(
    name = "com_google_breakpad",
    path = "third_party/google-breakpad",
)
