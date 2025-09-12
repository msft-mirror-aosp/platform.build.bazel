"""A repository rule that sets up aliases depending on host conditions."""

load(
    "//rules:repository_utils.bzl",
    "create_workspace_file",
    "default_workspace_file_content",
)

VALID_KEYS = ["os", "arch"]

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

def _validate_condition(cond):
    for k, v in cond.items():
        if k not in VALID_KEYS:
            fail("condition", k, "is not valid - must be one of", VALID_KEYS)
        elif k == "os" and v not in OS_MATCHER:
            fail("os name", v, "is not valid - must be one of", OS_MATCHER.keys())
        elif k == "arch" and v not in ARCH_MATCHER:
            fail("arch", v, "is not valid - must be one of", ARCH_MATCHER.keys())

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
        _validate_condition(cond)
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
