# Libvpx Bazel Registry Module (1.16.0.bcr.beta.1)

This directory contains the Bazel Central Registry (BCR) module definition and
build overlay files for `libvpx`.

## Overview

`libvpx` is the reference implementation of the VP8 and VP9 video codecs. Since
the upstream library uses an autotools/make-based build workflow, this Bazel
registry module overlays a native Bazel build (`BUILD.bazel`, Starlark files,
and custom compilers) over the extracted upstream source repository.

## Python Build Tooling Migration (No-Perl Mandate)

Historically, the upstream `libvpx` build process relies on several Perl scripts
(`rtcd.pl`, `ads2gas.pl`, etc.) to generate runtime CPU detection headers and
translate ARM assembly syntax files.

To make `libvpx` compiles fully portable and compile cleanly on platforms
without pre-installed Perl interpreters—most notably **Windows**—this overlay
has migrated all build generation steps to Python 3:

1. **[rtcd.py](overlay/rtcd.py)** (Replaced `rtcd.pl`):
   - Parsed by the custom `_libvpx_rtcd_header` rule in
     [defs.bzl](overlay/config/defs.bzl).
   - Dynamically translates Perl-based configuration DSL files (e.g.
     `vp8_rtcd_defs.pl`) to Python syntax on-the-fly, executes the translated
     configuration inside a sandboxed namespace, and outputs the equivalent C
     headers declaring optimized SIMD functions.
2. **[ads2gas.py](overlay/ads2gas.py)** (Replaced `ads2gas.pl` and `thumb.pm`):
   - Invoked via the `_libvpx_arm_asm_source` rule in
     [nasm.bzl](overlay/nasm.bzl).
   - Translates ARM Developer Suite (ADS/RVDS) assembly `.asm` source syntax
     into standard GNU Assembler (`.S`) format.

## Overlay Structure

- **`MODULE.bazel`**: Configures dependencies, introducing `rules_python` and
  eliminating `rules_perl`.
- **`overlay/`**: Files injected into the root of the fetched `libvpx` source:
  - **`BUILD.bazel`**: Root build target definitions.
  - **`ads2gas.py` / `rtcd.py`**: Python-based translators.
  - **`config/defs.bzl`**: Skylark rules generating the C RTCD headers.
  - **`nasm.bzl`**: Skylark rules compiling converted ARM assembly.
- **`source.json`**: Contains the source archive URL, overlay files, and
  integrity check hashes.

## Upgrading Upstream Releases (Maintainer Guide)

When upgrading this registry module to a newer upstream release of `libvpx`
(e.g. `1.17.0`), follow these steps to carry forward the Python-based overlay:

1. **Create the New Registry Directory:**
   - Copy the contents of the current version directory to a new directory named
     after the target version (e.g. `1.17.0`).
2. **Download and Verify the Upstream Archive:**
   - Fetch the new release tarball/zip from the WebM project.
   - Update `source.json` with the new archive URL, strip prefix, and computing
     the new SHA-256 hash.
3. **Compare Upstream build-system script changes:**
   - Check if upstream modified their Perl tools (`rtcd.pl`, `ads2gas.pl`,
     `thumb.pm`) in the new release.
   - If they did, update [rtcd.py](overlay/rtcd.py) or
     [ads2gas.py](overlay/ads2gas.py) to replicate any new parsing logic or
     syntax conversions.
4. **Re-evaluate DSL definition changes:**
   - Check if new `.pl` definition files (like `vp8_rtcd_defs.pl`) introduced
     new Perl expressions or functions that require adjustments in `rtcd.py`'s
     translation regexes.
5. **Recompute Checksum Hashes:**
   - Generate SHA-256 base64 integrity hashes for all modified or copied files
     in `overlay/` and update their values under the `"overlay"` key in the new
     version's `source.json`.
6. **Test the Build:**
   - Add a temporary direct dependency to `MODULE.bazel` of your main workspace
     to reference the new local module version and run:
     ```bash
     bazel test @libvpx//tests:smoke
     ```
   - Verify that all headers generate cleanly and compile successfully.
