"""Utility functions"""

load("@bazel_skylib//lib:types.bzl", "types")

def flatten(items):
    """Flattens a list / tuple of items.

    Due to recurrsion limitations in starlark, only 1 level of nesting is
    eliminated.

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

def tee_filter(items, condition):
    """Creates a truthy and a falsy list by checking a condition against each item.

    Args:
        items: An iterable of items.
        condition: A callable used to check each item. Called as
            "condition(x)".

    Returns:
        2 lists. The 1st list contains items with condition eval to true, and
        the 2nd list contains items with condition eval to false.
    """
    truthy, falsy = [], []
    for i in items:
        if condition(i):
            truthy.append(i)
        else:
            falsy.append(i)
    return truthy, falsy
