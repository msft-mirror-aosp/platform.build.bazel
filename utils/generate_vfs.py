#!/usr/bin/env python3
"""Generates a Clang Virtual File System (VFS) overlay YAML file.

A VFS overlay allows Clang to map a virtual directory structure to actual files
on the physical disk. This is particularly useful for:
1. Hermeticity: Ensuring the build only uses files from the specified SDK/MSVC.
2. Case-insensitivity on Linux: Mapping lowercase virtual paths to mixed-case
   real files.
3. Cross-compilation: Mapping absolute Windows paths to relative paths in the
   Bazel execution root.
"""

import argparse
import os
import yaml
from pathlib import Path


def build_tree(contents):
    """Builds a nested dictionary tree from relative paths.

    Args:
        contents: A list of tuples (rel_path, ext_path).

    Returns:
        A nested dictionary representing the directory structure.
    """
    tree = {}
    for rel_path, ext_path in contents:
        parts = Path(rel_path).parts
        current = tree
        for i, part in enumerate(parts):
            part_lower = part.lower()
            if i == len(parts) - 1:
                # Leaf node (file)
                # We lowercase all names in the VFS tree to ensure complete
                # case-insensitivity on Linux, which is crucial for finding
                # Windows headers and libraries.
                current[part_lower] = {
                    "type": "file",
                    "name": part_lower,
                    "external-contents": ext_path,
                }
            else:
                # Directory node
                if part_lower not in current:
                    current[part_lower] = {
                        "type": "directory",
                        "name": part_lower,
                        "contents": {},
                    }
                current = current[part_lower]["contents"]
    return tree


def tree_to_list(node_dict):
    """Converts the nested dictionary tree to VFS YAML structure.

    Args:
        node_dict: The nested dictionary from build_tree.

    Returns:
        A list of dictionaries in Clang VFS format.
    """
    l = []
    for key in sorted(node_dict.keys()):
        item = node_dict[key]
        if item["type"] == "directory":
            l.append(
                {
                    "type": "directory",
                    "name": item["name"],
                    "contents": tree_to_list(item["contents"]),
                }
            )
        else:
            l.append(item)
    return l


def generate_vfs_dict(files, virtual_root, external_root, strip_version=False):
    """Generates the VFS dictionary for a single root mapping.

    Args:
        files: A list of file paths to include in this root.
        virtual_root: The virtual path prefix (e.g., "c:/msvc").
        external_root: The physical path prefix on disk that should be
            stripped from the 'files' paths to determine their relative
            position under the virtual_root.
        strip_version: If True, strip directory components that look like
            Windows SDK versions (e.g. 10.0.22621.0).

    Returns:
        A dictionary representing the root entry for the VFS overlay.
    """
    external_root = str(external_root).rstrip("/")

    contents = []
    for f_str in sorted(files):
        if not f_str.strip():
            continue

        p = f_str.strip()

        # We MUST keep paths relative to the execution root (start with 'external/')
        # to ensure they work across different sandboxes.
        if external_root and external_root in p:
            idx = p.find(external_root)
            rel_path_raw = p[idx + len(external_root) :].lstrip("/")
            # Use the path as provided by Bazel (which is relative to execroot)
            ext_path = p

            if strip_version:
                # Strip 10.0.x.y components to flatten the versioned SDK structure.
                # This makes toolchain flags simpler and version-independent.
                parts = Path(rel_path_raw).parts
                new_parts = [part for part in parts if not part.startswith("10.0.")]
                rel_path = "/".join(new_parts)
            else:
                rel_path = rel_path_raw
        else:
            rel_path = os.path.basename(p)
            ext_path = p

        contents.append((rel_path, ext_path))

    tree = build_tree(contents)
    vfs_list = tree_to_list(tree)

    return {"type": "directory", "name": virtual_root, "contents": vfs_list}


def parse_file_list(path):
    """Parses a file containing a list of file paths, one per line.

    Args:
        path: Path to the manifest file.

    Returns:
        A list of cleaned path strings.
    """
    if not path or not os.path.exists(path):
        return []
    with open(path, "r") as f:
        return [line.strip() for line in f if line.strip()]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, help="Path to the output YAML file.")
    parser.add_argument(
        "--msvc-files", required=True, help="Manifest file for MSVC files."
    )
    parser.add_argument(
        "--sdk-files", required=True, help="Manifest file for Windows SDK files."
    )
    parser.add_argument(
        "--virtual-msvc-root", default="C:/msvc", help="Virtual path for MSVC files."
    )
    parser.add_argument(
        "--virtual-sdk-root", default="C:/sdk", help="Virtual path for SDK files."
    )
    parser.add_argument(
        "--external-msvc-root",
        default="",
        help="The physical path prefix for MSVC files that should be stripped "
        "when calculating their relative path within the virtual root.",
    )
    parser.add_argument(
        "--external-sdk-root",
        default="",
        help="The physical path prefix for SDK files that should be stripped "
        "when calculating their relative path within the virtual root.",
    )
    parser.add_argument(
        "--strip-sdk-version",
        action="store_true",
        help="If set, strip Windows SDK version components (e.g. 10.0.22621.0) "
        "from the virtual paths.",
    )
    args = parser.parse_args()

    msvc_paths = parse_file_list(args.msvc_files)
    sdk_paths = parse_file_list(args.sdk_files)

    vfs = {
        "version": 0,
        "case-sensitive": False,
        "use-external-names": False,
        "roots": [],
    }

    if msvc_paths:
        # We lowercase the virtual_root to be consistent with our lowercased tree.
        vfs["roots"].append(
            generate_vfs_dict(
                msvc_paths, args.virtual_msvc_root.lower(), args.external_msvc_root
            )
        )

    if sdk_paths:
        vfs["roots"].append(
            generate_vfs_dict(
                sdk_paths,
                args.virtual_sdk_root.lower(),
                args.external_sdk_root,
                strip_version=args.strip_sdk_version,
            )
        )

    with open(args.output, "w") as f:
        yaml.dump(vfs, f, default_flow_style=False)

    print(f"VFS overlay generated at {args.output}")


if __name__ == "__main__":
    main()
