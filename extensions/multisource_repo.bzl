"""Module extension to manage dependencies with multiple sources.

This extension provides a unified way to manage external dependencies that may
come from different locations depending on the build environment. It is
primarily used to support two main build flavors:

1.  **goog**: Internal Google builds that fetch large artifacts (SDKs, system
    images, toolchains) from Google Cloud Storage (gs://).
2.  **aosp**: External Android Open Source Project builds that fetch from
    public HTTP/HTTPS URLs or use local placeholder files to remain hermetic
    or avoid authentication issues.

The extension automatically selects the correct source based on the
'MULTISOURCE_REPO_TYPE' environment variable. It supports GCS (gs://), standard
HTTP/HTTPS URLs, and local labels (e.g., @repo//path/to/file).
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")
load("@rules_gcs//gcs:repo_rules.bzl", "gcs_archive", "gcs_file")

def _zip_link_repo_impl(ctx):
    """Implementation of the repository rule that standardizes zip file access.

    This rule is a crucial helper for maintaining a consistent interface across
    different dependency types. It creates a repository that contains exactly
    one file, symlinked from a source label.
    """
    source_path = ctx.path(ctx.attr.source_file)
    basename = source_path.basename
    ctx.symlink(source_path, "file/" + basename)
    ctx.file("file/BUILD.bazel", """
package(default_visibility = ['//visibility:public'])
filegroup(name = 'file', srcs = ['{}'])
""".format(basename))

zip_link_repo = repository_rule(
    implementation = _zip_link_repo_impl,
    doc = """Creates a standardized repository containing a single zip file.

This rule abstracts the source of a zip file by symlinking it from a label
(which could be a local file or a target in another repository) to a fixed
location within this repository.
""",
    attrs = {
        "source_file": attr.label(doc = "Label pointing to the zip file.", mandatory = True),
    },
)

def _multisource_repo_impl(ctx):
    """Implementation of the multisource_repo module extension.

    This extension resolves dependencies by:
    1.  Determining the active build flavor from the 'MULTISOURCE_REPO_TYPE'
        environment variable (defaulting to 'goog').
        Note: ctx.getenv automatically registers a dependency on this variable.
    2.  Collecting all 'archive' and 'file' definitions across all modules.
    3.  Selecting the source config matching the current build flavor for each dependency.
    4.  Instantiating the appropriate repository rule.
    """
    build_type = ctx.getenv("MULTISOURCE_REPO_TYPE", "goog")

    # Collect archives and their attributes
    archives = {}
    for mod in ctx.modules:
        for archive in mod.tags.archive:
            if archive.name not in archives:
                archives[archive.name] = archive

    # Collect files and their attributes
    files = {}
    for mod in ctx.modules:
        for file in mod.tags.file:
            if file.name not in files:
                files[file.name] = file

    # Helper to resolve source config and handle local files
    def _instantiate_dep(name, dep, is_archive):
        if build_type == "goog":
            source = dep.goog
        elif build_type == "aosp":
            source = dep.aosp
        else:
            fail("Unknown build type: " + build_type)

        if not source:
            fail("No source config found for {} in environment {}".format(name, build_type))

        # Check if local file is set
        local_file = source.get("local_file")
        if local_file:
            zip_link_repo(
                name = name,
                source_file = local_file,
            )
            return

        url = source.get("url")
        if not url:
            fail("Either 'local_file' or 'url' must be provided in source config for " + name)

        sha256 = source.get("sha256")
        if not sha256:
            fail("sha256 is mandatory for remote source: " + url)

        if is_archive:
            if url.startswith("gs://"):
                gcs_archive(
                    name = name,
                    url = url,
                    sha256 = sha256,
                    build_file = dep.build_file,
                    build_file_content = dep.build_file_content,
                    strip_prefix = dep.strip_prefix,
                    patch_strip = dep.patch_strip,
                    patches = dep.patches,
                )
            else:
                http_archive(
                    name = name,
                    urls = [url],
                    sha256 = sha256,
                    build_file = dep.build_file,
                    build_file_content = dep.build_file_content,
                    strip_prefix = dep.strip_prefix,
                    patch_strip = dep.patch_strip,
                    patches = dep.patches,
                )
        elif url.startswith("gs://"):
            gcs_file(
                name = name,
                url = url,
                sha256 = sha256,
            )
        else:
            download_name = name + "_download"
            http_file(
                name = download_name,
                urls = [url],
                sha256 = sha256,
            )
            zip_link_repo(
                name = name,
                source_file = "@" + download_name + "//file",
            )

    for name, archive in archives.items():
        _instantiate_dep(name, archive, is_archive = True)

    for name, file in files.items():
        _instantiate_dep(name, file, is_archive = False)

_archive_tag = tag_class(
    doc = "Defines a dependency archive with environment-specific sources.",
    attrs = {
        "name": attr.string(doc = "The canonical name of the repository.", mandatory = True),
        "build_file": attr.label(doc = "The BUILD file to use for this repository."),
        "build_file_content": attr.string(doc = "The content of the BUILD file to use for this repository."),
        "strip_prefix": attr.string(doc = "A directory prefix to strip from the extracted files."),
        "patch_strip": attr.int(doc = "The number of leading path segments to strip from patches."),
        "patches": attr.label_list(doc = "A list of patches to apply to the repository."),
        "goog": attr.string_dict(doc = "Google internal source config (url, sha256)."),
        "aosp": attr.string_dict(doc = "AOSP source config (url, local_file, sha256)."),
    },
)

_file_tag = tag_class(
    doc = "Defines a dependency file with environment-specific sources.",
    attrs = {
        "name": attr.string(doc = "The canonical name of the repository.", mandatory = True),
        "goog": attr.string_dict(doc = "Google internal source config (url, sha256)."),
        "aosp": attr.string_dict(doc = "AOSP source config (url, local_file, sha256)."),
    },
)

multisource_repo = module_extension(
    implementation = _multisource_repo_impl,
    doc = """Extension to manage multi-source dependencies.

This extension allows the build to remain portable between internal Google
infrastructure and public AOSP environments by abstracting the source of large
binary dependencies.
""",
    tag_classes = {
        "archive": _archive_tag,
        "file": _file_tag,
    },
)
