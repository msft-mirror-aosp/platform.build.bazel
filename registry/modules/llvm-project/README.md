# llvm-project (`21.1.8.aemu`)

Configured from upstream `llvm/llvm-project` `llvmorg-21.1.8` (`https://github.com/llvm/llvm-project/releases/tag/llvmorg-21.1.8`) using LLVM's `utils/bazel/llvm-project-overlay/` to build a shared `libLLVM.so` from source for `third_party/mesa3d` (`lavapipe` and `llvmpipe`).

## Custom Overlays (`21.1.8.aemu/overlay/`)

- **`MODULE.bazel` & `vars.bzl`**: Declares `llvm-project` `21.1.8.aemu` and sets `LLVM_VERSION_MAJOR = 21`, `LLVM_VERSION_MINOR = 1`, `LLVM_VERSION_PATCH = 8`.
- **`BUILD.bazel`**: Exposes `@llvm-project//:llvm` (aliasing `//llvm:llvm_shared`).
- **`llvm/targets.bzl`**:
  - Restricts `llvm_targets` to `["X86"]` for `linux-x86_64` software rasterization instead of compiling all backend architectures.
  - Wraps `cc_library` with `alwayslink = True` so all LLVM component object files are included when linking the shared `//llvm:libLLVM.so`.
- **`llvm/BUILD.bazel`**:
  - Defines `//llvm:libLLVM.so` (`linkshared = True`, `soname = libLLVM.so`, `-Wl,-Bsymbolic`, `-Wl,-Bsymbolic-functions`, `-Wl,-z,nodelete`, and a `LLVM_AEMU_21.1` symbol version script to isolate symbols from any host `libLLVM.so` loaded in the same process) and `//llvm:llvm_shared` (`srcs = [":libLLVM.so"]`, `deps = [":llvm_headers"]`), allowing `lavapipe` (`libvulkan_lvp.so`) and `llvmpipe` (`libgallium_dri.so`) to dynamically share a single source-built `libLLVM.so`.
  - Adds `-std=c++17` and `-fno-rtti` to `llvm_copts` (matching `mesa3d`'s `-fno-rtti` ABI) and splits C/assembly sources in `lib/Support` into `:Support_c`.
- **`llvm/include/llvm/CodeGen/RDFRegisters.h`**: Specializes `std::__make_transparent<std::less<llvm::rdf::RegisterRef>>` for compatibility with modern `libc++` where `std::less<RegisterRef>` is stateful (`PRI` member).
