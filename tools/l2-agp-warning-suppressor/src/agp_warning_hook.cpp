#include "agp_warning_hook.h"
#include <windows.h>
#include <MinHook.h>
#include <cwchar>
namespace {
using MessageBoxWFn = int (WINAPI*)(HWND, LPCWSTR, LPCWSTR, UINT);
MessageBoxWFn g_originalMessageBoxW = nullptr;
bool ContainsAgpWarning(const wchar_t* text) {
    if (!text) return false;
    constexpr wchar_t needle[] = L"agp is deactivated";
    constexpr size_t n = (sizeof(needle) / sizeof(needle[0])) - 1;
    for (const wchar_t* p = text; *p; ++p)
        if (_wcsnicmp(p, needle, n) == 0) return true;
    return false;
}
int WINAPI HookMessageBoxW(HWND hwnd, LPCWSTR text, LPCWSTR caption, UINT type) {
    if (ContainsAgpWarning(text)) return IDOK;
    return g_originalMessageBoxW ? g_originalMessageBoxW(hwnd, text, caption, type) : IDOK;
}
}
void agp_warning_hook::Install() {
    if (MH_Initialize() != MH_OK) return;
    if (MH_CreateHookApi(L"user32.dll", "MessageBoxW",
        reinterpret_cast<LPVOID>(&HookMessageBoxW),
        reinterpret_cast<LPVOID*>(&g_originalMessageBoxW)) != MH_OK) {
        MH_Uninitialize(); return;
    }
    if (MH_EnableHook(MH_ALL_HOOKS) != MH_OK) {
        MH_RemoveHook(MH_ALL_HOOKS); MH_Uninitialize();
    }
}
void agp_warning_hook::Remove() {
    MH_DisableHook(MH_ALL_HOOKS); MH_RemoveHook(MH_ALL_HOOKS); MH_Uninitialize();
}
