# Exports macOS SDK from Xcode or Command Line Tools directory.

load("@//build/bazel/toolchains/cc:rules.bzl", "sysroot")

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
