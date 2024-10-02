"""A repository rule that sets up aliases depending on host conditions."""

load(
    "//build/bazel/rules:repository_utils.bzl",
    "create_workspace_file",
    "default_workspace_file_content",
)

OS_MATCHER = {
    "windows": lambda os: os.startswith("windows"),
    "macos": lambda os: os.startswith("mac"),
    "linux": lambda os: os == "linux",
}

ARCH_MATCHER = {
    "x86": lambda arch: arch in ["x86", "i386"],
    "x64": lambda arch: arch in ["amd64", "x86_64"],
    "arm64": lambda arch: arch in ["aarch64", "arm64"],
}

ALIAS_TEMPL = """
alias(
    name = "host",
    actual = "{actual}",
    visibility = ["//visibility:public"],
)
"""

def host_conditions(os = None, arch = None):
    """Returns a string that encodes the given conditions.

    An item is checked only if not None, and the condition is considered a match
    unless there is a mismatched item. Therefore `host_conditions()` is a
    match-all condition.

    Args:
        os: The OS name ("windows", "macos", "linux")
        arch: The host architecture ("x86", "x64", "arm64").

    Returns:
        A string to be consumed by the "select_host_platform" rule.
    """
    cond = {}
    if os:
        if os not in OS_MATCHER:
            fail("os name", os, "is not valid - must be one of", OS_MATCHER.keys())
        cond["os"] = os
    if arch:
        if arch not in ARCH_MATCHER:
            fail("arch", arch, "is not valid - must be one of", ARCH_MATCHER.keys())
        cond["arch"] = arch
    return json.encode(cond)

def _is_cond_met(cond, repo_ctx):
    if "os" in cond:
        match_func = OS_MATCHER[cond["os"]]
        if not match_func(repo_ctx.os.name):
            return False
    if "arch" in cond:
        match_func = ARCH_MATCHER[cond["arch"]]
        if not match_func(repo_ctx.os.arch):
            return False
    return True

def _host_platform_repository_impl(repo_ctx):
    platform_target = None
    for cond, actual in repo_ctx.attr.host.items():
        cond = json.decode(cond)
        if _is_cond_met(cond, repo_ctx):
            platform_target = actual
    if not platform_target:
        fail(
            "The host OS doesn't meet any of the following conditions and is therefore unsupported:",
            repo_ctx.attr.host.keys(),
        )
    platform_target = Label(platform_target)
    build_content = ALIAS_TEMPL.format(actual = platform_target)
    repo_ctx.file("BUILD.bazel", build_content, executable = False)
    create_workspace_file(None, repo_ctx, default_workspace_file_content(
        repo_ctx.name,
        "host_platform_repository",
    ))

host_platform_repository = repository_rule(
    implementation = _host_platform_repository_impl,
    local = True,
    doc = "Creates a repository with a `host` target, that points to platform targets depending on host conditions.",
    attrs = {
        "host": attr.string_dict(
            doc = "A map with keys being conditions (as returned by `host_conditions()`), and values being the platform target the alias should resolve to.",
            allow_empty = False,
            mandatory = True,
        ),
    },
)
