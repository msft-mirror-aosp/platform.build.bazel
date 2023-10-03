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

# keep sorted
ALL_FRAMEWORKS = [
    "CFNetwork",
    "CoreFoundation",
    "CoreGraphics",
    "CoreServices",
    "DiskArbitration",
    "Foundation",
    "IOKit",
    "Security",
]

cc_toolchain_import(
    name = "frameworks",
    framework_paths = [":System/Library/Frameworks"],
    support_files = glob([
        "System/Library/Frameworks/{}.framework/**".format(f)
        for f in ALL_FRAMEWORKS
    ]),
)
