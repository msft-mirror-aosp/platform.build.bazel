"""Module extension providing repositories for custom toolchains."""

load("@bazel_tools//tools/build_defs/repo:local.bzl", "new_local_repository")
load("@rules_gcs//gcs:repo_rules.bzl", "gcs_archive")
load("//rules:overlay_repository.bzl", "overlay_repository")
load("//toolchains/cc:repository_rules.bzl", "msvc_tools_repository", "windows_sdk_repository", "xcode_tools_repository")

def _toolchain_impl(ctx):
    # type: (module_ctx) -> None
    tool_versions = {}  # type: dict[string, string]
    version_file_tag = _get_singleton_tag(ctx.modules, "version_file")
    if version_file_tag:
        tool_versions = json.decode(ctx.read(version_file_tag.label))  # type: dict[string, string]

    clang_tag = _get_singleton_tag(ctx.modules, "clang")
    if clang_tag:
        if clang_tag.version:
            tool_versions["clang"] = clang_tag.version
        if not tool_versions.get("clang"):
            fail("clang version is missing from tag", clang_tag)

        # Repositories that provide the clang compilers
        new_local_repository(
            name = "clang_linux_x64",
            build_file = "//toolchains/cc/linux_clang:clang.BUILD",
            path = "{}/linux-x86/{}".format(clang_tag.root_path, tool_versions["clang"]),
        )
        new_local_repository(
            name = "clang_mac_all",
            build_file = "//toolchains/cc/mac_clang:clang.BUILD",
            path = "{}/darwin-x86/{}".format(clang_tag.root_path, tool_versions["clang"]),
        )
        new_local_repository(
            name = "clang_win_x64",
            build_file = "//toolchains/cc/windows_clang:clang.BUILD",
            path = "{}/windows-x86/{}".format(clang_tag.root_path, tool_versions["clang"]),
        )

        overlay_repository(
            name = "gcc_lib",
            path = "prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8",
            not_found_ok = True,
            overlay_files = {"BUILD.bazel": "//toolchains/cc/linux_clang:gcc_lib.BUILD"},
        )

        # Hermetic SDKs
        gcs_archive(
            name = "xcode_tools_hermetic",
            build_file = "//toolchains/cc/mac_clang:xcode.BUILD",
            sha256 = "e1fca4bee5f88bd6d3108e380235860a5a0cb5cec17d664e98ad0c3e58675f77",
            url = "gs://emu-next-bazel/hermetic-xcode/xcode_command_line_tools-16.2-202505191216.zip",
        )
        gcs_archive(
            name = "vctools_hermetic",
            build_file = "//toolchains/cc/windows_clang:vctools.BUILD",
            sha256 = "41c278147d9633427a7f9d606f43db42345b92b80e358a182e7e7047f4ddd4a0",
            url = "gs://emu-next-bazel/hermetic-msvc/msvc_tools_14_50_35717_202601231558.zip",
        )
        gcs_archive(
            name = "windows_sdk_hermetic",
            build_file = "//toolchains/cc/windows_clang:sdk.BUILD",
            sha256 = "44451a7b5d9c8785f0bf19e747ab25c21b1717d73aa9e636eb5be57049f33841",
            url = "gs://emu-next-bazel/hermetic-msvc/windows_11_sdk_10.0.22621.0_202506021733.zip",
        )

        gcs_archive(
            name = "arm_sysroot",
            build_file = "//toolchains/cc/linux_arm64_clang:sysroot.BUILD",
            patch_strip = 1,
            patches = ["//toolchains/cc/linux_arm64_clang/patches:Resolve-libc-relative-to-sysroot-aarch64_none_linux_gnu.patch"],
            sha256 = "12fcdf13a7430655229b20438a49e8566e26551ba08759922cdaf4695b0d4e23",
            strip_prefix = "arm-gnu-toolchain-13.2.Rel1-x86_64-aarch64-none-linux-gnu",
            # We could also use an http_archive with the following URL for open-source:
            # https://developer.arm.com/-/media/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz?rev=22c39fc25e5541818967b4ff5a09ef3e&hash=B9FEDC2947EB21151985C2DC534ECCEC
            url = "gs://emu-next-bazel/arm-toolchain/arm-gnu-toolchain-13.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz",
        )

        # Host SDKs
        if ctx.os.name.lower().startswith("windows") and ctx.getenv("CC_ALLOW_HOST_SDK", "1") in ("1", "true"):
            msvc_tools_repository(
                name = "vctools",
                build_file = "//toolchains/cc/windows_clang:vctools.BUILD",
            )
            windows_sdk_repository(
                name = "windows_sdk",
                build_file = "//toolchains/cc/windows_clang:sdk.BUILD",
                sdk_path = "C:\\Program Files (x86)\\Windows Kits\\10",
            )
        else:
            # dummy
            overlay_repository(
                name = "vctools",
                path = "build/bazel/no-such-dir",
                not_found_ok = True,
                overlay_files = {"BUILD.bazel": "//toolchains/cc/windows_clang:vctools.BUILD"},
            )
            overlay_repository(
                name = "windows_sdk",
                path = "build/bazel/no-such-dir",
                not_found_ok = True,
                overlay_files = {"BUILD.bazel": "//toolchains/cc/windows_clang:sdk.BUILD"},
            )

        if ctx.os.name.lower().startswith("mac") and ctx.getenv("CC_ALLOW_HOST_SDK", "1") in ("1", "true"):
            xcode_tools_repository(
                name = "xcode_tools",
                build_file = "//toolchains/cc/mac_clang:xcode.BUILD",
            )
        else:
            # dummy
            overlay_repository(
                name = "xcode_tools",
                path = "build/bazel/no-such-dir",
                not_found_ok = True,
                overlay_files = {"BUILD.bazel": "//toolchains/cc/mac_clang:xcode.BUILD"},
            )

    java_tag = _get_singleton_tag(ctx.modules, "java")
    if java_tag:
        if java_tag.version:
            tool_versions["java"] = java_tag.version
        if not tool_versions.get("java"):
            fail("java version is missing from tag", java_tag)

        new_local_repository(
            name = "jdk_linux",
            build_file = "//toolchains/java:linux_jdk.BUILD",
            path = "{}/{}/linux".format(java_tag.root_path, tool_versions["java"]),
        )
        new_local_repository(
            name = "jdk_mac_arm64",
            build_file = "//toolchains/java:mac_jdk.BUILD",
            path = "{}/{}/mac-arm64/Contents/Home".format(java_tag.root_path, tool_versions["java"]),
        )
        new_local_repository(
            name = "jdk_windows",
            build_file = "//toolchains/java:windows_jdk.BUILD",
            path = "{}/{}/win".format(java_tag.root_path, tool_versions["java"]),
        )

    toolchain_hub_files = {
        "cc/linux_clang/BUILD.bazel": "//toolchains/cc/linux_clang:toolchain.BUILD" if clang_tag else None,
        "cc/mac_clang/BUILD.bazel": "//toolchains/cc/mac_clang:toolchain.BUILD" if clang_tag else None,
        "cc/windows_clang/BUILD.bazel": "//toolchains/cc/windows_clang:toolchain.BUILD" if clang_tag else None,
        "cc/linux_arm64_clang/BUILD.bazel": "//toolchains/cc/linux_arm64_clang:toolchain.BUILD" if clang_tag else None,
        "java/linux/BUILD.bazel": "//toolchains/java:linux_toolchain.BUILD" if java_tag else None,
        "java/mac_arm64/BUILD.bazel": "//toolchains/java:mac_arm64_toolchain.BUILD" if java_tag else None,
        "java/windows/BUILD.bazel": "//toolchains/java:windows_toolchain.BUILD" if java_tag else None,
        "toolchains/cc/rules.bzl": "//toolchains/cc:rules.bzl",
    }
    overlay_repository(
        name = "toolchain_hub",
        overlay_files = {k: v for k, v in toolchain_hub_files.items() if v},
        overlay_contents = {k: "" for k, v in toolchain_hub_files.items() if not v},
    )

    return ctx.extension_metadata(reproducible = True)

def _get_singleton_tag(modules, tag_class_name):
    for mod in modules:
        if not mod.is_root:
            continue
        tags = getattr(mod.tags, tag_class_name)
        if len(tags) == 1:
            return tags[0]
        elif len(tags) > 1:
            fail("multiple tags defined for", tag_class_name, ": ", tags)
    return None

_clang = tag_class(
    doc = "Hermetic CC toolchain based on android clang and gcc prebuilts.",
    attrs = {
        "root_path": attr.string(doc = "Workspace relative path up to (but excluding) host platform triples", mandatory = True),
        "version": attr.string(doc = "Directory name of the versioned clang toolchain."),
    },
)
_java = tag_class(
    doc = "The Java toolchain based on studio jdk prebuilts.",
    attrs = {
        "root_path": attr.string(doc = "Workspace relative path up to (but excluding) host platform triples", mandatory = True),
        "version": attr.string(doc = "Directory name of the versioned java toolchain."),
    },
)
_version_file = tag_class(
    doc = "A json file defining default toolchain versions.",
    attrs = {
        "label": attr.label(doc = "The label to the file.", allow_single_file = True, mandatory = True),
    },
)
toolchain = module_extension(
    doc = """Import custom toolchains from either the repo or the host.

    Has no effect if called from a submodule. Each tag class can only be called once.
    """,
    implementation = _toolchain_impl,
    tag_classes = {
        "clang": _clang,
        "java": _java,
        "version_file": _version_file,
    },
    os_dependent = True,
)
