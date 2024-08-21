load("@bazel_skylib//rules:copy_file.bzl", "copy_file")
load("@bazel_skylib//rules:native_binary.bzl", "native_binary")
load("@rules_rust//rust:toolchain.bzl", "rust_stdlib_filegroup")

filegroup(
    name = "rustc",
    srcs = ["bin/rustc.exe"],
    visibility = ["//visibility:public"],
)

copy_file(
    name = "libgcc_s_seh",
    src = "@mingw64//:x86_64-w64-mingw32/lib/libgcc_s_seh-1.dll",
    out = "bin/libgcc_s_seh-1.dll",
    allow_symlink = True,
)

copy_file(
    name = "libwinpthread",
    src = "@mingw64//:x86_64-w64-mingw32/bin/libwinpthread-1.dll",
    out = "bin/libwinpthread-1.dll",
    allow_symlink = True,
)

filegroup(
    name = "rustc_lib",
    srcs = glob(["bin/*.dll"]) + [
        ":libgcc_s_seh",
        ":libwinpthread",
    ],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "rustdoc",
    srcs = ["bin/rustdoc.exe"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "clippy_driver_bin",
    srcs = ["bin/clippy-driver.exe"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "cargo",
    srcs = ["bin/cargo.exe"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "rustfmt_bin",
    srcs = ["bin/rustfmt.exe"],
    visibility = ["//visibility:public"],
)

native_binary(
    name = "rustfmt",
    src = ":rustfmt_bin",
)

rust_stdlib_filegroup(
    name = "rust_std_x64",
    srcs = glob(
        [
            "lib/rustlib/x86_64-pc-windows-gnu/lib/*.rlib",
            "lib/rustlib/x86_64-pc-windows-gnu/lib/*.dll*",
            "lib/rustlib/x86_64-pc-windows-gnu/lib/*.o",
            "lib/rustlib/x86_64-pc-windows-gnu/lib/self-contained/**",
        ],
    ),
    visibility = ["//visibility:public"],
)
