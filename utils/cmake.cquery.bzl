"""This query helper prints out the following items for a target, to be consumed
by a cmake rule:

* The output archive file of the target.
* The include paths.
* The public defines.
"""

def format(target):
    """Returns info needed by cmake in a json string.

    Args:
        target: the target object passed from cquery.

    Returns:
        A json string that looks like:
        {
            "archive": "path/to/archive",
            "includes": "path1;path2;...",
            "defines": "key1;key2=val;...",
        }
        paths are all relative to workspace root.
    """
    compilation_context = providers(target).get("CcInfo").compilation_context

    quote_includes = compilation_context.quote_includes.to_list()
    system_includes = compilation_context.system_includes.to_list()

    # includes seems to be always empty, but we don't care and treat it the
    # same as others.
    includes = compilation_context.includes.to_list()
    combined_includes = _uniq([
        i
        for i in quote_includes + system_includes + includes
        if not i.startswith("bazel-out/")
    ])

    archive = providers(target).get("OutputGroupInfo").archive.to_list()[0]

    defines = compilation_context.defines.to_list()

    json_struct = {
        "archive": archive.path,
        "includes": ";".join(["bazel-out/../" + p for p in combined_includes]),
        "defines": ";".join(defines),
    }

    return json.encode(json_struct)

def _uniq(hashables):
    uniq = dict([(o, None) for o in hashables])
    return uniq.keys()
