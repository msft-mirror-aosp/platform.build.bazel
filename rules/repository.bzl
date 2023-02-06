"""Custom repository rules.

Requires bazel 6.0.0+ due to usage of repository_ctx.workspace_root
"""

def _default_workspace_file_content(name):
    return """# DO NOT EDIT: automatically generated WORKSPACE file
workspace(name = \"{name}\")
""".format(name = name)

def _is_windows(repo_ctx):
    os = repo_ctx.os.name.lower()
    return os.startswith("windows")

def _list_files_command_unix(path, repo_ctx):
    find_binary = repo_ctx.which("find")
    if not find_binary:
        fail("Cannot list directory", path, ": \"find\" is not in PATH.")
    return [find_binary, path, "-type", "f,l"]

def _list_files_command_windows(path, repo_ctx):
    cmd_binary = repo_ctx.which("cmd.exe")
    if not cmd_binary:
        fail("Cannot list directory", path, ": \"cmd.exe\" is not in PATH.")
    return [cmd_binary, "/c", "\"dir {} /a-d /s /b\"".format(path)]

def _list_files_recursive(path, repo_ctx):
    """Lists all the files / symlinks under path, recursively.

    Directories are recursed into but not included in the list. It does not
    follow symlinks.

    Args:
        path: The path to list. The behavior of path not being a directory is
          undefined.
        repo_ctx: A repository_ctx object.

    Returns:
        A list of strings, each item is a path for each file / symlink,
          relative to the list path.
    """
    if _is_windows(repo_ctx):
        command = _list_files_command_windows(path, repo_ctx)
    else:
        command = _list_files_command_unix(path, repo_ctx)
    result = repo_ctx.execute(command, working_directory = path)
    if result.return_code != 0:
        fail("Command failed:", " ".join(command), ",", "returns", result.return_code, result.stderr)
    return [_relative_path(f, path) for f in result.stdout.splitlines()]

def _is_abs_path(path_str):
    return path_str[0] == "/" or path_str[1:3] == ":\\" or path_str[0] == "\\"

def _path_separator(repo_ctx):
    return "\\" if _is_windows(repo_ctx) else "/"

def _resolve_path(path_str, repo_ctx):
    """Resolves path_str relative to the workspace root to an absolute path."""
    if _is_abs_path(path_str):
        return repo_ctx.path(path_str)
    full_path = _path_separator(repo_ctx).join([str(repo_ctx.workspace_root), path_str])
    return repo_ctx.path(full_path)

def _relative_path(path_str, root):
    """Returns the path relative to root for path_str.

    Works only if both path_str and root are absolute, and path_str is a subpath of root.
    """
    return path_str.removeprefix(root).lstrip("/\\")

def _file_is_ignored(path_seg, ignored_basenames):
    return path_seg[-1] in ignored_basenames

def _path_ancestors(path_seg):
    return [path_seg[:i] for i in range(1, len(path_seg))]

def _find_collapsable_ancestor(path_seg, non_collapsable_directories):
    for i in range(1, len(path_seg)):
        if path_seg[:i] not in non_collapsable_directories:
            return path_seg[:i]
    return path_seg

def _filter_and_collapse(files, ignored_basenames, path_separator):
    """This function processes a list of files and returns a list of paths for symlinking.

    It filters out all the file entries to ignore, and uses that information
    to find out the minimum set of symlinks to create provided that the ignored
    entries are excluded from the generated file tree.
    """
    filepaths_in_segments = [tuple(f.split(path_separator)) for f in files]
    non_collapsable_directories = {}
    keep_files = []
    for file_seg in filepaths_in_segments:
        if _file_is_ignored(file_seg, ignored_basenames):
            non_collapsable_directories.update([(p, None) for p in _path_ancestors(file_seg)])
        else:
            keep_files.append(file_seg)

    link_paths = {_find_collapsable_ancestor(p, non_collapsable_directories): None for p in keep_files}
    return [path_separator.join(p) for p in link_paths]

def _selective_local_repository_impl(repo_ctx):
    # Create shadow directory in the repository path.
    src_root = _resolve_path(repo_ctx.attr.path, repo_ctx)
    if not src_root.exists:
        fail("Cannot create repository", repo_ctx.name, ": path", src_root, "is not found.")
    src_root = str(src_root.realpath)

    files = _list_files_recursive(src_root, repo_ctx)
    path_sep = _path_separator(repo_ctx)
    link_paths = _filter_and_collapse(files, repo_ctx.attr.ignore_filenames, path_sep)

    for dest in link_paths:
        src = path_sep.join([src_root, dest])
        repo_ctx.symlink(src, dest)

    # Link BUILD file
    repo_ctx.delete("BUILD.bazel")
    build_file = _resolve_path(repo_ctx.attr.build_file, repo_ctx)
    if not build_file.exists:
        fail("Cannot create repository", repo_ctx.name, ": BUILD file", build_file, "is not found.")
    repo_ctx.symlink(build_file, "BUILD.bazel")

    # Link / Create WORKSAPCE file
    repo_ctx.delete("WORKSPACE.bazel")
    if repo_ctx.attr.workspace_file:
        workspace_file = _resolve_path(repo_ctx.attr.workspace_file, repo_ctx)
        if not workspace_file.exists:
            fail("Cannot create repository", repo_ctx.name, ": WORKSPACE file", workspace_file, "is not found.")
        repo_ctx.symlink(workspace_file, "WORKSPACE.bazel")
    else:
        repo_ctx.file("WORKSPACE.bazel", _default_workspace_file_content(repo_ctx.name), executable = False)

selective_local_repository = repository_rule(
    implementation = _selective_local_repository_impl,
    local = True,
    doc = "A repository rule similar to new_local_repository, but allows to ignore certain files.",
    attrs = {
        "build_file": attr.string(doc = "A file to use as a BUILD file for this directory, relative to the main workspace.", mandatory = True),
        "ignore_filenames": attr.string_list(doc = "Base filenames to ignore.", default = []),
        "path": attr.string(doc = "A path on the local filesystem. This can be either absolute or relative to the main workspace.", mandatory = True),
        "workspace_file": attr.string(doc = "The file to use as the WORKSPACE file for this repository, relative to the main workspace."),
    },
)
