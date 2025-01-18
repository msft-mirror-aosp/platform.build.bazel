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
            "SDKs/MacOSX.sdk/usr/include/**",
            "SDKs/MacOSX.sdk/usr/lib/**",
        ],
        exclude = [
            "SDKs/MacOSX.sdk/usr/include/c++/**",
        ],
    ),
    path = "SDKs/MacOSX.sdk",
)

cc_toolchain_import(
    name = "libcxx",
    include_paths = [
        ":SDKs/MacOSX.sdk/usr/include/c++/v1",
    ],
    lib_search_paths = [
        ":SDKs/MacOSX.sdk/usr/lib",
    ],
    support_files = glob(
        [
            "SDKs/MacOSX.sdk/usr/include/c++/v1/**",
            "SDKs/MacOSX.sdk/usr/lib/libc++.*",
            "SDKs/MacOSX.sdk/usr/lib/libc++abi.*",
        ],
    ),
)

# keep sorted
ALL_FRAMEWORKS = [
    "AVFAudio",
    "AVFoundation",
    "AppKit",
    "ApplicationServices",
    "CFNetwork",
    "Carbon",
    "CloudKit",
    "Cocoa",
    "ColorSync",
    "CoreAudio",
    "CoreAudioTypes",
    "CoreData",
    "CoreFoundation",
    "CoreGraphics",
    "CoreImage",
    "CoreLocation",
    "CoreMedia",
    "CoreServices",
    "CoreText",
    "CoreVideo",
    "DiskArbitration",
    "Foundation",
    "Hypervisor",
    "IOKit",
    "IOSurface",
    "ImageIO",
    "Metal",
    "OpenCL",
    "OpenGL",
    "QuartzCore",
    "Security",
    "Symbols",
    "VideoToolbox",
    "vmnet",
]

cc_toolchain_import(
    name = "frameworks",
    framework_paths = [":SDKs/MacOSX.sdk/System/Library/Frameworks"],
    support_files = glob([
        "SDKs/MacOSX.sdk/System/Library/Frameworks/{}.framework/**".format(f)
        for f in ALL_FRAMEWORKS
    ]),
)
