package(default_visibility = ["@//build/bazel/toolchains/python:__subpackages__"])

filegroup(
    name = "linux_x86_files",
    srcs = glob(
        [
            "linux-x86/bin/**",
            "linux-x86/lib/**",
        ],
        exclude = [
            "**/* *",
            "linux-x86/lib/pkgconfig/**",
            "**/*.pyc",
        ],
    ),
)

filegroup(
    name = "linux_x86_interpreter",
    srcs = ["linux-x86/bin/python3"],
)

filegroup(
    name = "windows_x86_files",
    srcs = glob(
        [
            "windows-x86/*",
            "windows-x86/DLLs/**",
            "windows-x86/Lib/**",
            "windows-x86/libs/**",
        ],
        exclude = [
            "**/*.pyc",
        ],
    ),
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
        exclude = [
            "**/* *",
            "darwin-x86/lib/pkgconfig/**",
            "**/*.pyc",
        ],
    ),
)

filegroup(
    name = "mac_all_interpreter",
    srcs = ["darwin-x86/bin/python3"],
)
