load("@bazel_tools//tools/jdk:default_java_toolchain.bzl", "BASE_JDK9_JVM_OPTS", "default_java_toolchain")

# use jdk17 toolchain when '--java_runtime_version=jdk17' flag is provided
config_setting(
    name = "jdk17_name_setting",
    values = {"java_runtime_version": "jdk17"},
    visibility = ["//visibility:private"],
)

toolchain(
    name = "java_runtime_toolchain",
    exec_compatible_with = ["@platforms//os:macos"],
    target_settings = [":jdk17_name_setting"],
    toolchain = "@jdk_mac_arm64//:jdk17_runtime",
    toolchain_type = "@bazel_tools//tools/jdk:runtime_toolchain_type",
)

# import minimal options from default_java_toolchain.bzl to avoid --patch-module arguments
# custom javac build hasn't been necessary since JDK 13, and it fails with JDK17
# https://github.com/bazelbuild/bazel/issues/14474#issuecomment-1001071398
JDK17_JVM_OPTS = BASE_JDK9_JVM_OPTS + [
    "--add-opens=jdk.compiler/com.sun.tools.javac.platform=ALL-UNNAMED",  # for buildjar.ReducedClasspathJavaLibraryBuilder
]

# Commands usefull for for debugging java toolchain issues
# bazel build  --verbose_failures --subcommands=pretty_print  --toolchain_resolution_debug=java /...
# bazel query //prebuilts/studio/jdk/jdk17:java17_compile_toolchain  --output=build

[
    default_java_toolchain(
        name = "java%s_compile_toolchain" % version,
        exec_compatible_with = ["@platforms//os:macos"],
        java_runtime = "@jdk_mac_arm64//:jdk17_runtime",
        jvm_opts = JDK17_JVM_OPTS,
        source_version = version,
        target_version = version,
    )
    for version in ("8", "11", "17")
]

toolchain(
    name = "bootstrap_runtime_toolchain_type",
    exec_compatible_with = ["@platforms//os:macos"],
    target_settings = [":jdk17_name_setting"],
    toolchain = "@jdk_mac_arm64//:jdk17_runtime",
    toolchain_type = "@bazel_tools//tools/jdk:bootstrap_runtime_toolchain_type",
)
