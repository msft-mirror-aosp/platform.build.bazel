# Exports macOS SDK from Xcode or Command Line Tools directory.

load(
    "@//build/bazel/toolchains/cc:rules.bzl",
    "cc_toolchain_import",
    "sysroot",
)

package(default_visibility = ["@//build/bazel/toolchains/cc:__subpackages__"])

sysroot(
    name = "sdk",
    all_files = glob(
        [
            "usr/include/**",
            "usr/lib/**",
        ],
    ),
)

cc_toolchain_import(
    name = "frameworks",
    framework_paths = [":System/Library/Frameworks"],
    support_files = glob([
        "System/Library/Frameworks/CoreFoundation.framework/**",
    ]),
)