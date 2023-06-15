"""Toolchain repository rules."""

load(
    "@//build/bazel/rules:repository_utils.bzl",
    "create_build_file",
    "create_workspace_file",
    "default_workspace_file_content",
    "relative_path",
    "resolve_workspace_path",
    "run_command",
)

def _macos_sdk_repository_impl(repo_ctx):
    """Creates a local repository for macOS SDK from the currently selected Xcode toolchain."""
    versions = repo_ctx.attr.sdk_versions if repo_ctx.attr.sdk_versions else [""]
    result = None
    for version in versions:
        result = run_command([
            "xcrun",
            "--sdk",
            "macosx{}".format(version),
            "--show-sdk-path",
        ], repo_ctx, check = False)
        if result.return_code == 0:
            break
    if result.return_code != 0:
        fail("None of the following macOS SDK versions are found:", versions)
    sdk_path = result.stdout.strip()
    for entry in resolve_workspace_path(sdk_path, repo_ctx).readdir():
        repo_ctx.symlink(entry, relative_path(str(entry), sdk_path))
    create_build_file(repo_ctx.attr.build_file, repo_ctx)
    create_workspace_file(None, repo_ctx, default_workspace_file_content(
        repo_ctx.name,
        "macos_sdk_repository",
    ))

macos_sdk_repository = repository_rule(
    implementation = _macos_sdk_repository_impl,
    local = True,
    doc = "Creates a local repository for macOS SDK from the currently " +
          "selected Xcode toolchain.",
    attrs = {
        "build_file": attr.string(
            doc = "A file to use as a BUILD file for this directory, " +
                  "relative to the main workspace.",
            mandatory = True,
        ),
        "sdk_versions": attr.string_list(
            doc = "The SDK versions to look for in the toolchain (e.g. 12.4, " +
                  "13.3). The first version found will be used. An empty " +
                  "string can be added at the end for the default SDK.",
            default = [""],
        ),
    },
)
