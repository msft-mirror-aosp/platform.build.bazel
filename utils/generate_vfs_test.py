"""Unit tests for the Clang VFS overlay generator.

These tests verify the core logic of generate_vfs.py, including:
- Path mapping from physical to virtual structures.
- Correct directory nesting in the generated YAML tree.
- Manifest file parsing.
"""

import unittest
import yaml
import tempfile
from pathlib import Path
import sys
import os


class TestVfsGenerator(unittest.TestCase):
    def test_basic_vfs_structure(self):
        """Verifies that the YAML has the correct mandatory fields."""
        from generate_vfs import generate_vfs_dict

        files = ["msvc/include/stdio.h"]
        # generate_vfs_dict returns a single root entry, not the full VFS
        root = generate_vfs_dict(files, "C:/msvc", "external/vctools/msvc")

        self.assertEqual(root["type"], "directory")
        self.assertEqual(root["name"], "C:/msvc")
        self.assertTrue(len(root["contents"]) > 0)

    def test_path_mapping(self):
        """Verifies that a file is correctly mapped to its virtual and external path."""
        from generate_vfs import generate_vfs_dict

        # In Bazel, the paths will be absolute or relative to the exec root.
        # Here we simulate files that are inside the external_root.
        files = ["external/vctools/msvc/include/stdio.h"]
        virtual_root = "C:/msvc"
        external_root = "external/vctools/msvc"

        root = generate_vfs_dict(files, virtual_root, external_root)

        # The tree structure is nested.
        # C:/msvc -> include -> stdio.h
        self.assertEqual(root["name"], "C:/msvc")
        include_dir = next(e for e in root["contents"] if e["name"] == "include")
        self.assertEqual(include_dir["type"], "directory")

        stdio_h = next(e for e in include_dir["contents"] if e["name"] == "stdio.h")
        self.assertEqual(stdio_h["type"], "file")
        self.assertEqual(
            stdio_h["external-contents"],
            "external/vctools/msvc/include/stdio.h",
        )

    def test_directory_nesting(self):
        """Verifies that multiple files are grouped correctly."""
        from generate_vfs import generate_vfs_dict

        files = [
            "external/vctools/msvc/include/stdio.h",
            "external/vctools/msvc/include/string.h",
            "external/vctools/msvc/lib/x64/msvcrt.lib",
        ]
        root = generate_vfs_dict(files, "C:/msvc", "external/vctools/msvc")

        # include/ dir
        include_dir = next(e for e in root["contents"] if e["name"] == "include")
        include_names = [e["name"] for e in include_dir["contents"]]
        self.assertIn("stdio.h", include_names)
        self.assertIn("string.h", include_names)

        # lib/ dir
        lib_dir = next(e for e in root["contents"] if e["name"] == "lib")
        x64_dir = next(e for e in lib_dir["contents"] if e["name"] == "x64")
        self.assertIn("msvcrt.lib", [e["name"] for e in x64_dir["contents"]])

    def test_parse_file_list(self):
        """Verifies that a list of files is parsed correctly."""
        from generate_vfs import parse_file_list

        content = "file1.h\n  file2.h  \n\nfile3.h"
        with tempfile.NamedTemporaryFile(mode="w", delete=False) as f:
            f.write(content)
            temp_path = Path(f.name)

        try:
            paths = parse_file_list(temp_path)
            self.assertEqual(len(paths), 3)
            self.assertIn("file1.h", paths)
            self.assertIn("file2.h", paths)
            self.assertIn("file3.h", paths)
        finally:
            temp_path.unlink()


if __name__ == "__main__":
    # Ensure the current directory is in sys.path so we can import generate_vfs
    sys.path.append(os.path.dirname(__file__))
    unittest.main()
