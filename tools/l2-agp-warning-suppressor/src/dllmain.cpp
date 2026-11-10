#include <windows.h>
#include "agp_warning_hook.h"
bool LoadSystemDinput8();
BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(instance);
        LoadSystemDinput8();
        agp_warning_hook::Install();
    } else if (reason == DLL_PROCESS_DETACH) {
        agp_warning_hook::Remove();
    }
    return TRUE;
}
