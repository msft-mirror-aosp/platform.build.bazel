def format(target):
    """Return paths of all the exported headers by a library, relative to workspace."""
    public_headers = providers(target).get("CcInfo").compilation_context.direct_public_headers
    return "\n".join([_get_path(f) for f in public_headers])

def _get_path(file):
    return "bazel-out/../" + file.path
