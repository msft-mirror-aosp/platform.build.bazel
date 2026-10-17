load(
    "@goldfish_build//toolchains/cc:actions.bzl",
    "ARCHIVER_ACTIONS",
    "ASSEMBLE_ACTIONS",
    "CPP_COMPILE_ACTIONS",
    "C_COMPILE_ACTIONS",
    "LINK_ACTIONS",
    "OBJC_COMPILE_ACTIONS",
)
load(
    "@goldfish_build//toolchains/cc:rules.bzl",
    "cc_tool",
    "cc_toolchain_import",
)

package(default_visibility = ["@toolchain_hub//:__subpackages__"])

filegroup(
    name = "llvm_cov",
    srcs = ["bin/llvm-cov.exe"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "llvm_profdata",
    srcs = ["bin/llvm-profdata.exe"],
    visibility = ["//visibility:public"],
)

cc_tool(
    name = "clang-cl",
    applied_actions = C_COMPILE_ACTIONS + OBJC_COMPILE_ACTIONS + CPP_COMPILE_ACTIONS,
    runfiles = glob(
        ["bin/clang*"],
        exclude = [
            "bin/clang-check.exe",
            "bin/clang-format.exe",
            "bin/clang-scan-deps.exe",
            "bin/clang-tidy.exe",
        ],
    ) + [
        ":bin/libwinpthread-1.dll",
    ],
    tool = ":bin/clang-cl.exe",
    visibility = ["//visibility:public"],
)

cc_tool(
    name = "clang-cl-assembler",
    applied_actions = ASSEMBLE_ACTIONS,
    runfiles = glob(
        ["bin/clang*"],
        exclude = [
            "bin/clang-check.exe",
            "bin/clang-format.exe",
            "bin/clang-scan-deps.exe",
            "bin/clang-tidy.exe",
        ],
    ) + [
        ":bin/libwinpthread-1.dll",
    ],
    tool = ":bin/clang-cl.exe",
)

cc_tool(
    name = "link",
    applied_actions = LINK_ACTIONS,
    runfiles = glob(["bin/*lld.exe"]) + [
        ":bin/libwinpthread-1.dll",
        ":bin/libxml2.dll",
    ],
    tool = ":bin/lld-link.exe",
    visibility = ["//visibility:public"],
)

cc_tool(
    name = "archiver",
    applied_actions = ARCHIVER_ACTIONS,
    runfiles = [
        ":bin/llvm-ar.exe",
        ":bin/libwinpthread-1.dll",
    ],
    tool = ":bin/llvm-lib.exe",
)

cc_tool(
    name = "clang-tidy",
    applied_actions = ["clang-tidy"],
    runfiles = glob(["bin/clang-tidy*"]),
    tool = ":bin/clang-tidy.exe",
)

cc_toolchain_import(
    name = "compiler_runtime",
    include_paths = glob(
        ["lib/clang/*/include"],
        exclude_directories = 0,
    ),
    support_files = glob(["lib/clang/*/include/**"]),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "other_binaries",
    srcs = [
        "bin/lld-link.exe",
        "bin/llvm-ar.exe",
        "bin/llvm-lib.exe",
        "bin/llvm-nm.exe",
        "bin/llvm-objcopy.exe",
        "bin/llvm-objdump.exe",
        "bin/llvm-ranlib.exe",
        "bin/llvm-rc.exe",
        "bin/llvm-strings.exe",
        "bin/llvm-strip.exe",
        "bin/llvm-windres.exe",
    ],
    visibility = ["//visibility:public"],
)
