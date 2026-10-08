# Copyright 2026 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Tests that Breakpad .sym files extracted from Rust cdylibs contain DWARF/PDB debug info."""

import sys
import unittest
from pathlib import Path


class RustBreakpadSymbolsTest(unittest.TestCase):
    """Verifies Breakpad symbol extraction for Rust shared libraries."""

    def setUp(self):
        super().setUp()
        if len(sys.argv) < 2:
            self.fail(
                "Expected path to extracted Breakpad .sym file as first argument."
            )
        self.sym_path = Path(sys.argv[1])
        self.assertTrue(
            self.sym_path.is_file(),
            f"Breakpad symbol file does not exist at {self.sym_path}",
        )
        self.lines = self.sym_path.read_text(encoding="utf-8").splitlines()

    def test_has_valid_module_header(self):
        self.assertGreater(len(self.lines), 0, "Breakpad .sym file is empty.")
        header = self.lines[0]
        parts = header.split()
        self.assertGreaterEqual(
            len(parts),
            5,
            f"Malformed MODULE header in {self.sym_path}: {header!r}",
        )
        self.assertEqual(parts[0], "MODULE")
        self.assertNotEqual(
            parts[3],
            "000000000000000000000000000000000",
            f"MODULE debug ID is all zeros in {self.sym_path}: {header!r}",
        )

    def test_contains_rust_source_file_records(self):
        file_records = [line for line in self.lines if line.startswith("FILE ")]
        self.assertTrue(
            any("rust_symbol_fixture.rs" in line for line in file_records),
            "Expected FILE record for 'rust_symbol_fixture.rs' in Breakpad "
            f".sym file ({self.sym_path}), but found {len(file_records)} FILE "
            "records. This indicates rustc stripped debug info or the PDB/dSYM "
            "was not passed to dump_syms.",
        )

    def test_contains_func_records_with_line_mappings(self):
        func_records = [line for line in self.lines if line.startswith("FUNC ")]
        self.assertTrue(
            any("rust_symbol_fixture_compute" in line for line in func_records),
            "Expected FUNC record (not just PUBLIC export) for "
            f"'rust_symbol_fixture_compute' in {self.sym_path}, but found "
            f"{len(func_records)} FUNC records.",
        )
        self.assertTrue(
            any("internal_rust_helper" in line for line in func_records),
            "Expected FUNC record for private Rust function "
            f"'internal_rust_helper' in {self.sym_path}.",
        )


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])
