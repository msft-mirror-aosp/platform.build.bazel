load("@//build/bazel/toolchains/cc:cc_toolchain_config.bzl", "cc_tools")
load(
    "@//build/bazel/toolchains/cc:cc_toolchain_import.bzl",
    "cc_toolchain_import",
)

package(default_visibility = ["@//build/bazel/toolchains/cc:__subpackages__"])

# The clang path definition for each platform
CLANG_LINUX_X64 = "linux-x86/clang-r487747"

target_linux_x64 = ":" + CLANG_LINUX_X64

cc_tools(
    name = "linux_x64",
    ar = target_linux_x64 + "/bin/llvm-ar",
    ar_features = [
        "archiver_flags",
    ],
    cxx = target_linux_x64 + "/bin/clang++",
    cxx_features = [
        "no_implicit_libs",
        "supports_pic",
        "supports_start_end_lib",
        "supports_dynamic_linker",
    ],
    gcc = target_linux_x64 + "/bin/clang",
    gcc_features = [
        "no_implicit_libs",
        "supports_pic",
        "supports_start_end_lib",
        "supports_dynamic_linker",
    ],
    ld = target_linux_x64 + "/bin/clang++",
    ld_features = [
        "force_pic_flags",
        "libraries_to_link",
        "library_search_directories",
        "linker_param_file",
        "linkstamps",
        "no_implicit_libs",
        "output_execpath_flags",
        "runtime_library_search_directories",
        "shared_flag",
        "static_link_cpp_runtimes",
        "strip_debug_symbols",
        "supports_dynamic_linker",
        "supports_pic",
        "supports_start_end_lib",
        "user_link_flags",
    ],
    strip = target_linux_x64 + "/bin/llvm-strip",
    tool_files = glob(
        [CLANG_LINUX_X64 + "/bin/*"],
        allow_empty = False,
    ),
)

cc_toolchain_import(
    name = "linux_x64_libcxx",
    hdrs = glob(
        [
            CLANG_LINUX_X64 + "/include/c++/v1/**",
            CLANG_LINUX_X64 + "/lib64/clang/17/include/**",
        ],
        allow_empty = False,
    ),
    dynamic_mode_libs = [
        target_linux_x64 + "/lib64/libc++.so",
        target_linux_x64 + "/lib64/libc++.so.1",
    ],
    include_paths = [
        target_linux_x64 + "/include/c++/v1",
        target_linux_x64 + "/lib64/clang/17/include",
    ],
    is_runtime_lib = True,
    static_mode_libs = [
        target_linux_x64 + "/lib64/libc++.a",
    ],
    deps = [
        "@gcc_lib//:libc",
        "@gcc_lib//:libgcc",
        "@gcc_lib//:libgcc_s",
        "@gcc_lib//:libm",
        "@gcc_lib//:libpthread",
        "@gcc_lib//:librt",
    ],
)
