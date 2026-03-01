#include <windows.h>
#include <stddef.h>

// Reproduces a compiler config issue, this compilation
// should succeed without modifying the BUILD.bazel in this directory.
typedef max_align_t qemu_max_align_t;

__declspec(dllexport) void HelloWorld() {
    MessageBoxA(NULL, "Hello from DLL!", "DLL", MB_OK);
}
