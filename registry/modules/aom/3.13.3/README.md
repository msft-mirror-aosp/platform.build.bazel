# Libaom Bazel Module Registry (v3.13.3)

This directory defines the Bzlmod registry configuration for building the
Alliance for Open Media (AOM) AV1 codec library (`libaom`) in our hermetic Bazel
workspace.

---

## 1. Registry Architecture & Files

The registry configuration consists of the following components:

- **`MODULE.bazel`**: Declares the module dependencies, including `rules_python`
  (v1.6.3), `rules_cc`, `rules_nasm`, and `nasm`.
- **`source.json`**: Specifies the upstream source archive (from
  `aom.googlesource.com`), its SHA-256 checksum, and a dictionary of all custom
  overlay files mapped to their SHA-256 SRI integrity hashes.
- **`overlay/`**: Custom files overlayed on top of the unpacked upstream source
  directory at build time:
  - **`BUILD.bazel`**: Defines target rules for compiling static library
    variants, handling CPU architectures (x86*64, aarch64), setting up compiler
    flags (`CONFIG*\_`and`HAVE\_\_`), and declaring `rtcd_gen` rules.
  - **`bazel/rtcd.py`**: A custom Python compiler tool that transpiles
    Perl-based RTCD configurations into C headers.
  - **`bazel/rtcd.bzl`**: Exposes the `rtcd_gen` macro executing `rtcd.py` under
    the Bazel action execution graph.
  - **`bazel/aom_config.bzl`**: Generates `aom_config.h` and `aom_config.asm`
    dynamically based on Bazel feature flag settings.
  - **`test/BUILD.bazel`**: Defines individual unit tests for library
    validation.

---

## 2. Python RTCD Compiler (`bazel/rtcd.py`)

To eliminate rule-chain dependencies on Perl (`@rules_perl`), which is poorly
supported on Windows build agents, the original `rtcd.pl` tool was replaced with
a custom transpilation pipeline: `rtcd.py`.

### How it Works

1.  **Transpilation (`compile_perl_to_python`)**:
    - Preprocesses Perl files to merge multi-line statements not ending in `;`
      or curly braces `{`/`}`.
    - Converts Perl-specific syntax to Python equivalents:
      - Ternary operators `(COND) ? V1 : V2` -> `V1 if COND else V2`.
      - Logical negation `!` -> `not `.
      - Regex operations `=~` / `!~` -> `re.search(...)`.
      - Array prefix annotations `@` -> bare list structures.
      - `foreach` loops and statement modifiers (`STATEMENT if CONDITION;`).
      - Perl string variable interpolations `"aom_${pred}_predictor"` -> Python
        f-strings `f"aom_{pred}_predictor"`.
2.  **Execution Namespace (`BarewordDict`)**:
    - The transpiled DSL is executed dynamically via Python's `exec()`.
    - To prevent variable resolution crashes due to Perl's loose bareword string
      evaluations, the namespace is wrapped in a fallback class
      (`BarewordDict`), resolving undefined identifiers to their own names as
      string values.
3.  **Config Parser**:
    - Parses the C config header (`aom_config.h`) produced by `aom_config.bzl`.
    - Handles `#define CONFIG_XYZ 1/0` lines, converting `1` to `"yes"` and `0`
      to `"no"` to align with Perl conditional expectations.
4.  **Autovivification Protections**:
    - Safeguards the `specialize` function with verification checks
      (`if fn not in ALL_FUNCS: return`). If a target prototype (e.g.
      `aom_sad_skip_16x8`) is gated off for a specific config ($h < 16$), its
      registration overrides are safely skipped.

---

## 3. BCR Migration Guide: Adopting an Upstream public BCR Version

If we decide to migrate from this local registry version to a public release on
the **Bazel Central Registry (BCR)**, keep the following considerations and
steps in mind:

### Key Differences to Look Out For:

1. **Perl Toolchain Dependency**: The upstream BCR module likely relies on the
   standard `@rules_perl` toolchain to run `rtcd.pl`. Because rules_perl has
   issues on Windows RBE configurations in our workspace, verify if the BCR
   version introduces Perl dependency chains. If it does, we must preserve or
   port our `rtcd.py` tool.
2. **Missing Custom Config Maps**: Our local setup customizes `aom_config.bzl`
   to control variables dynamically (e.g. `CONFIG_REALTIME_ONLY=1` mapping to
   `CONFIG_QUANT_MATRIX=0`). Verify if the BCR version hardcodes config headers
   or allows customization via flags.
3. **Missing Windows RBE Workarounds**: Check if Windows-specific flags (like
   `--enable_runfiles` under MSVC RBE configs) are handled correctly in the
   upstream test rules.

### Migration Checklist:

#### Step 1: Declare the BCR Dependency & Overrides

1. Remove our local `aom` module from our local registry folder.
2. Add `bazel_dep(name = "aom", version = "<BCR_VERSION>")` in the root
   `MODULE.bazel`.
3. If the BCR version lacks our custom fixes (like `rtcd.py` or compile
   selects), use a `single_version_override` in our root `MODULE.bazel` to apply
   them as local patches:
   ```bazel
   single_version_override(
       module_name = "aom",
       version = "<BCR_VERSION>",
       patches = [
           "//build/bazel/patches:aom_python_rtcd.patch",
           "//build/bazel/patches:aom_custom_config.patch",
       ],
       patch_strip = 1,
   )
   ```

#### Step 2: Compare Build Targets & Configurations

1. Verify if the upstream `aom` build rules select the correct SIMD directories
   for `aarch64` (neon) and `x86_64` (sse2/sse3/avx2) automatically.
2. Ensure that our target optimizations (`sse4_2` on x86, `arm_crc32` on ARM64)
   are properly generated and compiled.

#### Step 3: Run Validation & Test Suites

1. Run local tests:
   ```bash
   bazel test @aom//test/...
   ```
2. Verify cross-platform remote compilation on Windows executors:
   ```bash
   bazel build --config=rbe-win-x64 @aom//test/...
   ```
3. Refresh the Bazel module lockfile:
   ```bash
   bazel mod deps --lockfile_mode=refresh
   ```
