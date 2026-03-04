# rules_rust 0.68.1.aemu Patches

This directory contains a custom version of `rules_rust` with specific patches required for the Android Emulator (AEMU) build environment. These patches primarily address challenges in cross-compiling Rust code for Windows targets from macOS and Linux hosts using a hermetic toolchain and `lld-link`.

## Patches

### 1. `aemu_rustc-cdylib-fix.patch`

**Problem:**
Standard `rules_rust` logic for Windows `cdylib` (DLL) targets sometimes fails to correctly identify or propagate the produced import library (`.lib` or `.dll.lib`). This is especially problematic in cross-compilation scenarios where we bypass the default `rustc` linker wrapper and use Bazel's `cc_common.link` directly to maintain better control over the linking process and ensure hermeticity.

**Solution:**
- Corrects the file extension handling for interface libraries on Windows (ensuring `.dll.lib` is recognized when appropriate).
- Ensures that `establish_cc_info` is called with the correct `interface_library` for `cdylib` targets.
- Forces the inclusion of `libstd` and allocator information when building `cdylib` and `staticlib` on Windows, ensuring all necessary symbols are present for the final link.

**Why for Cross-Compilation?**
When cross-compiling, the standard assumptions about where the linker puts output files or how they are named can break. This patch ensures that Bazel's C++ rules (which often consume these Rust outputs) receive the correct metadata to link against the resulting DLLs.

---

### 2. `aemu_windows-allocator.patch`

**Problem:**
Since Rust 1.81, the compiler mangles the symbols for the allocator shim (the bridge between the `alloc` crate and the actual memory allocator). Symbols like `__rust_alloc` are now referenced by `std` using complex mangled names.

In the AEMU hermetic build, we often use `cc_common.link` for the final link step. Because Windows does not support "weak symbols" in the same way Linux does, the default `rules_rust` mechanism for providing these allocator shims can be unreliable or difficult to configure for cross-compilation.

**The Mangling (`_RNvCskdKJRKLKjqM_...`):**
The patch introduces `allocator_library_windows.rs`, which manually defines the allocator shim functions using explicit `export_name` attributes with v0 mangled names.

Example: `_RNvCskdKJRKLKjqM_7___rustc12___rust_alloc`
- `_RNv`: v0 mangling prefix.
- `CskdKJRKLKjqM`: The hash `kdKJRKLKjqM` is specific to the `rustc` version (`1.91.1`) and the internal `__rustc` crate used for the shim.
- `7___rustc12___rust_alloc`: Identifies the `__rust_alloc` function within the internal `___rustc` namespace.

**Why do we need it?**
- **Symbol Resolution:** Without these exact mangled names, the linker will report "undefined symbol" errors because the pre-compiled `std` library in our toolchain is looking for these specific names, not the unmangled `__rust_alloc`.
- **Windows Constraints:** Since we cannot rely on weak symbol resolution on Windows, we provide a single, definitive implementation of these shims that our linker (`lld-link`) can find.
- **Cross-Compilation Stability:** By hardcoding these for our specific toolchain version, we ensure that our cross-compilation remains stable even when the host environment or Bazel configuration changes.

**Why for Cross-Compilation?**
In a native build, `rustc` normally handles the generation of this shim automatically. However, when we take control of the linking process via Bazel's `cc_common.link` (which is necessary for our hermetic, cross-platform toolchain), we must provide these internal compiler-generated symbols ourselves.
