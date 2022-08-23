"""Utility functions"""

load("@bazel_skylib//lib:types.bzl", "types")

def flatten(items):
    """Flattens a list / tuple of items.

    Args:
        items: A list or tuple to flatten.

    Returns:
        A list with flattened items.
    """
    ret = []
    for item in items:
        if types.is_list(item) or types.is_tuple(item):
            ret.extend(item)
        else:
            ret.append(item)
    return ret
