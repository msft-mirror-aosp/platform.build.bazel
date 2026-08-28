# Android Emulator Bazel Build System

This directory contains the Bazel build system configuration and utilities for the Android Emulator (AEMU).

## Repository Overview

This repository is structured to support a hermetic, reproducible build of the Android Emulator and its associated tools (e.g., `netsim`, `rootcanal`). It integrates various components including QEMU, GFXstream, and Rutabaga, managing their dependencies and build configurations through Bazel.

Key directories:
- `build/bazel`: Central Bazel configuration, extensions, and common rules.
- `hardware/generic/goldfish`: The main emulator source code and plugin logic.
- `third_party`: External dependencies mirrored or linked into the workspace.
- `prebuilts`: Host toolchains and pre-compiled binaries (SDKs, JDKs, etc.).

## Bazel Structure

The build utilizes **Bzlmod** for dependency management. The root `MODULE.bazel` file (symlinked from `build/bazel/toplevel.MODULE.bazel`) defines the external dependencies.

### Local Registry Override

To manage local modifications to upstream Bazel modules and to package internal components as modules, we use a **Local Bazel Registry** located at `build/bazel/registry`.

The `.bazelrc` configures Bazel to prioritize this local registry:
```bazel
common --registry=file:///%workspace%/build/bazel/registry
common --registry=https://bcr.bazel.build
```

Most modules in this repository (e.g., `@goldfish`, `@aemu`, `@qemu`) are defined in `build/bazel/registry/modules` and use `source.json` to point to their actual source locations within the git repo using `local_path`. This allows us to treat different parts of the monorepo as distinct Bazel modules while keeping them in a single git repository.

## AOSP Builds

To support building in the Android Open Source Project (AOSP) environment, where access to internal Google Cloud Storage buckets is not available, the build system supports an `aosp` configuration variant.

This variant automatically switches the source of certain dependencies (like system images and toolchains) to public URLs or dummy files (like for Fishtank).

### Usage

To build or test using the AOSP configuration, add `--config=aosp` to your Bazel command:

```bash
bzl build --config=aosp @goldfish//...
bzl test --config=aosp @goldfish_test//ets:presubmit
```

This flag sets the `MULTISOURCE_REPO_TYPE=aosp` repository environment variable, which is read by the `multisource_repo` module extension to select the appropriate sources defined in `MODULE.bazel`.

## Dependency Management (`multisource_repo`)

The build relies on several large binaries, SDKs, and test assets. To keep the git repository lean, these are stored externally and fetched during the build.

Instead of relying on a hardcoded central bucket or environment variables, dependencies are managed using the `multisource_repo` module extension. This allows specifying different sources for different environments (e.g., `goog` for internal Google builds, `aosp` for external builds) directly in `MODULE.bazel`.

### Structure in `MODULE.bazel`

Dependencies are defined using `multisource_repo.archive` (or `multisource_repo.file`) tags, with `goog` and `aosp` configuration dictionaries defined inline:

```python
multisource_repo.archive(
    name = "tradefed",
    goog = {
        "url": "gs://emu-next-bazel/ab/tradefed/...",
        "sha256": "...",
    },
    aosp = {
        "url": "https://dl.google.com/android/repository/...",
        "sha256": "...",
    },
)
```

#### Expected Content & AOSP Migration Plan

The GCS bucket (default: `gs://emu-next-bazel`) hosts several critical dependencies for the Android Emulator Bazel build. To support the migration to AOSP, we need to address these dependencies as outlined below.

#### 1. Toolchains
These are required for reproducible builds, particularly on Windows.

*   **Xcode Command Line Tools**:
    *   `hermetic-xcode/xcode_command_line_tools-16.2-202505191216.zip`
    *   **AOSP Status**: **Will not be provided**. Users must rely on host tools or provide their own.
*   **MSVC & Windows SDK**:
    *   `hermetic-msvc/msvc_tools_14_50_35717_202601231558.zip`
    *   `hermetic-msvc/windows_11_sdk_10.0.22621.0_202506021733.zip`
    *   **AOSP Status**: **Not provided**. Users must create their own packages if they wish to use the `--hermetic` flag (recommended to prevent random build failures from using host tools). This can be done using [create_hermetic_packages.py](utils/create_hermetic_packages.py). See [utils/README.md](utils/README.md) for details.
*   **ARM Toolchain**:
    *   `arm-toolchain/arm-gnu-toolchain-13.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz`
    *   **AOSP Status**: **Available**. The build has been updated to use the `multisource_repo` extension, which automatically falls back to the public ARM developer URL when building with `--config=aosp`.

#### 2. System Images for Testing
These are used for emulator integration testing.

*   **Android 16k Images**:
    *   `android16k-x86_64`
    *   `android16k-arm64-v8a`
    *   **AOSP Status**: **Available**. We use official public SDK images for AOSP users.

## Key Utilities

These scripts are located in [utils/](utils/).

### [create_hermetic_packages.py](utils/create_hermetic_packages.py)
Creates and uploads hermetic toolchain packages (MSVC, Windows SDK) to GCS.

**Usage:**
```bash
python utils/create_hermetic_packages.py {msvc|sdk} [options]
```
**Common Options:**
*   `--upload`: Upload the resulting zip file to GCS.
*   `--gcs-bucket <bucket>`: Override the default bucket.
*   `--update-bzl`: Automatically update `extensions/toolchain.bzl` with the new URL and SHA256.

### [update_sysimage.py](utils/update_sysimage.py)
Manages the update and upload of system images to the GCS bucket, and updates the `goog` source entries in `MODULE.bazel`. (Internal Google use only).

**Usage:**
```bash
python utils/update_sysimage.py -b BUILD_ID [options]
```
**Options:**
*   `-b, --build-id <id>`: Fetch from internal Android Build.
*   `--gcs-bucket <bucket>`: Override the target GCS bucket.
*   `-f, --force`: Force download and upload even if the file exists on GCS.
*   `-v, --verbose`: Enable verbose logging.

## Clang-Tidy Configuration

The build system includes first-class support for `clang-tidy` integration via Bazel aspects. The `clang_tidy_test` rules operate over the C++ dependency graph and ensure that code styling and static analysis modernize the codebase in an automated, transactional basis.

### Enabling Clang-Tidy Validation

To invoke clang-tidy validation during a test or build phase, pass the following flag:
```bash
--@goldfish_build//:clang_tidy_enabled=true
```

### Performance & Diagnostic Scoping

Parsing every C++ source file heavily burdens the build system and generates significant noise from legacy code. We use a combination of flags to scope the analysis down to single files and specific line numbers (e.g. for precommit hooks or `emu-dev-cli tidy` refactoring pipelines):

1. **Limit the Aspect AST Evaluation (`clang_tidy_check_files`)**
   Use this to restrict the Bazel aspect to a minimal set of source files. This works via a string suffix match against file paths and drastically speeds up the evaluation time.
   ```bash
   --@goldfish_build//:clang_tidy_check_files="foo.cc"
   --@goldfish_build//:clang_tidy_check_files="bar.h"
   ```

2. **Restrict Emitted Diagnostics (`clang_tidy_line_filter`)**
   Even when parsing `foo.cc`, limit the generated report to lines actually modified by passing the native `clang-tidy` line filter block format encoded as JSON.
   ```bash
   --@goldfish_build//:clang_tidy_line_filter='[{"name": "foo.cc", "lines": [[10, 20]]}]'
   ```
