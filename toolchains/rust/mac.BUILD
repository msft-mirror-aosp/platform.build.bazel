load("@bazel_skylib//rules:native_binary.bzl", "native_binary")
load("@rules_rust//rust:toolchain.bzl", "rust_stdlib_filegroup")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "rustc",
    srcs = ["bin/rustc"],
)

filegroup(
    name = "rustc_lib",
    srcs = glob(["lib/*.dylib*"]),
)

filegroup(
    name = "rustdoc",
    srcs = ["bin/rustdoc"],
)

filegroup(
    name = "clippy_driver_bin",
    srcs = ["bin/clippy-driver"],
)

filegroup(
    name = "cargo",
    srcs = ["bin/cargo"],
)

filegroup(
    name = "rustfmt_bin",
    srcs = ["bin/rustfmt"],
)

native_binary(
    name = "rustfmt",
    src = ":rustfmt_bin",
    out = "rustfmt",
)

filegroup(
    name = "llvm_cov_bin",
    srcs = ["lib/rustlib/aarch64-apple-darwin/bin/llvm-cov"],
)

filegroup(
    name = "llvm_profdata_bin",
    srcs = ["lib/rustlib/aarch64-apple-darwin/bin/llvm-profdata"],
)

rust_stdlib_filegroup(
    name = "rust_std_arm64",
    srcs = glob(["lib/rustlib/aarch64-apple-darwin/lib/*.rlib"]),
)

rust_stdlib_filegroup(
    name = "rust_std_x64",
    srcs = glob(["lib/rustlib/x86_64-apple-darwin/lib/*.rlib"]),
)
