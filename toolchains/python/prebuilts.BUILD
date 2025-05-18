load("@rules_python//python:defs.bzl", "py_runtime", "py_runtime_pair")

package(default_visibility = ["@//build/bazel/toolchains/python:__subpackages__"])

filegroup(
    name = "linux_x86_files",
    srcs = glob(
        [
            "linux-x86/bin/**",
            "linux-x86/lib/**",
        ],
        allow_empty = True,
        exclude = [
            "**/* *",
            "linux-x86/lib/pkgconfig/**",
            "**/*.pyc",
            "**/__pycache__/**",
        ],
    ),
    target_compatible_with = ["@platforms//os:linux"],
)

filegroup(
    name = "linux_x86_interpreter",
    srcs = ["linux-x86/bin/python3"],
    target_compatible_with = ["@platforms//os:linux"],
)

filegroup(
    name = "windows_x86_files",
    srcs = glob(
        [
            "windows-x86/*",
            "windows-x86/DLLs/**",
            "windows-x86/Lib/**",
            "windows-x86/libs/**",
            "**/__pycache__/**",
        ],
        allow_empty = True,
        exclude = [
            "**/*.pyc",
        ],
    ),
    target_compatible_with = ["@platforms//os:windows"],
)

filegroup(
    name = "windows_x86_interpreter",
    srcs = ["windows-x86/python.exe"],
)

filegroup(
    name = "mac_all_files",
    srcs = glob(
        [
            "darwin-x86/bin/**",
            "darwin-x86/lib/**",
        ],
        allow_empty = True,
        exclude = [
            "**/* *",
            "darwin-x86/lib/pkgconfig/**",
            "**/*.pyc",
            "**/__pycache__/**",
        ],
    ),
    target_compatible_with = ["@platforms//os:macos"],
)

filegroup(
    name = "mac_all_interpreter",
    srcs = ["darwin-x86/bin/python3"],
    target_compatible_with = ["@platforms//os:macos"],
)

py_runtime(
    name = "linux_x86_python3",
    files = [":linux_x86_files"],
    interpreter = ":linux_x86_interpreter",
    python_version = "PY3",
)

py_runtime_pair(
    name = "linux_x86_py_runtime_pair",
    py2_runtime = None,
    py3_runtime = ":linux_x86_python3",
)

toolchain(
    name = "linux_x86_toolchain",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ],
    target_compatible_with = ["@platforms//os:linux"],
    toolchain = ":linux_x86_py_runtime_pair",
    toolchain_type = "@bazel_tools//tools/python:toolchain_type",
    visibility = ["//visibility:public"],
)

py_runtime(
    name = "windows_x86_python3",
    files = [":windows_x86_files"],
    interpreter = ":windows_x86_interpreter",
    python_version = "PY3",
)

py_runtime_pair(
    name = "windows_x86_py_runtime_pair",
    py2_runtime = None,
    py3_runtime = ":windows_x86_python3",
)

toolchain(
    name = "windows_x86_toolchain",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
    target_compatible_with = ["@platforms//os:windows"],
    toolchain = ":windows_x86_py_runtime_pair",
    toolchain_type = "@bazel_tools//tools/python:toolchain_type",
    visibility = ["//visibility:public"],
)

py_runtime(
    name = "mac_all_python3",
    files = [":mac_all_files"],
    interpreter = ":mac_all_interpreter",
    python_version = "PY3",
)

py_runtime_pair(
    name = "mac_all_py_runtime_pair",
    py2_runtime = None,
    py3_runtime = ":mac_all_python3",
)

toolchain(
    name = "mac_all_toolchain",
    exec_compatible_with = [
        "@platforms//os:macos",
    ],
    target_compatible_with = ["@platforms//os:macos"],
    toolchain = ":mac_all_py_runtime_pair",
    toolchain_type = "@bazel_tools//tools/python:toolchain_type",
    visibility = ["//visibility:public"],
)
