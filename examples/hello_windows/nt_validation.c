#include <windows.h>
#include <stdio.h>

// RtlGetVersion is in ntdll.lib
// We use POSVERSIONINFOW which is already defined in winnt.h (included via windows.h)
__declspec(dllimport) LONG NTAPI RtlGetVersion(PRTL_OSVERSIONINFOW lpVersionInformation);

int main() {
    RTL_OSVERSIONINFOW osvi;
    osvi.dwOSVersionInfoSize = sizeof(RTL_OSVERSIONINFOW);
    if (RtlGetVersion(&osvi) == 0) {
        printf("Successfully called ntdll!RtlGetVersion\n");
        printf("Windows Version: %lu.%lu (Build %lu)\n", 
               osvi.dwMajorVersion, osvi.dwMinorVersion, osvi.dwBuildNumber);
    } else {
        printf("Failed to call ntdll!RtlGetVersion\n");
        return 1;
    }
    return 0;
}
