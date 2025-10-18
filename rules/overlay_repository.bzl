"""A repository rule to create free-form overlay repositories."""

load(
    "//rules:repository_utils.bzl",
    "create_repo_file",
)

def _overlay_repository_impl(repo_ctx):
    """Creates a repository with overlays."""
    for dest_path, src in repo_ctx.attr.overlay_files.items():
        repo_ctx.symlink(src, dest_path)
    for dest_path, contents in repo_ctx.attr.overlay_contents.items():
        repo_ctx.file(dest_path, contents, executable = False)

    create_repo_file(repo_ctx)

overlay_repository = repository_rule(
    implementation = _overlay_repository_impl,
    local = True,
    doc = "Creates a repository with overlays.",
    attrs = {
        "overlay_files": attr.string_keyed_label_dict(
            doc = "A dictionary where keys are dest paths in the repo and values are labels of the sources.",
        ),
        "overlay_contents": attr.string_dict(
            doc = "A dictionary where keys are dest paths in the repo and values are contents of the files.",
        ),
    },
)
