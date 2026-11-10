#include <windows.h>
#include <dinput.h>
#include <string>
namespace {
HMODULE g_systemDinput8 = nullptr;
FARPROC Resolve(const char* name) { return g_systemDinput8 ? GetProcAddress(g_systemDinput8, name) : nullptr; }
}
bool LoadSystemDinput8() {
    if (g_systemDinput8) return true;
    wchar_t path[MAX_PATH]{};
    const UINT length = GetSystemDirectoryW(path, MAX_PATH);
    if (!length || length + 13 >= MAX_PATH) return false;
    std::wstring fullPath(path, length);
    fullPath += L"\\dinput8.dll";
    g_systemDinput8 = LoadLibraryW(fullPath.c_str());
    return g_systemDinput8 != nullptr;
}
extern "C" HRESULT WINAPI ProxyDirectInput8Create(HINSTANCE i, DWORD v, REFIID r, LPVOID* o, LPUNKNOWN p) {
    using Fn = HRESULT (WINAPI*)(HINSTANCE,DWORD,REFIID,LPVOID*,LPUNKNOWN);
    auto fn = reinterpret_cast<Fn>(Resolve("DirectInput8Create")); return fn ? fn(i,v,r,o,p) : E_FAIL;
}
extern "C" HRESULT WINAPI ProxyDllCanUnloadNow() {
    using Fn = HRESULT (WINAPI*)(); auto fn = reinterpret_cast<Fn>(Resolve("DllCanUnloadNow")); return fn ? fn() : E_FAIL;
}
extern "C" HRESULT WINAPI ProxyDllGetClassObject(REFCLSID c, REFIID r, LPVOID* o) {
    using Fn = HRESULT (WINAPI*)(REFCLSID,REFIID,LPVOID*); auto fn = reinterpret_cast<Fn>(Resolve("DllGetClassObject")); return fn ? fn(c,r,o) : E_FAIL;
}
extern "C" HRESULT WINAPI ProxyDllRegisterServer() {
    using Fn = HRESULT (WINAPI*)(); auto fn = reinterpret_cast<Fn>(Resolve("DllRegisterServer")); return fn ? fn() : E_FAIL;
}
extern "C" HRESULT WINAPI ProxyDllUnregisterServer() {
    using Fn = HRESULT (WINAPI*)(); auto fn = reinterpret_cast<Fn>(Resolve("DllUnregisterServer")); return fn ? fn() : E_FAIL;
}
extern "C" LPCDIDATAFORMAT WINAPI ProxyGetdfDIJoystick() {
    using Fn = LPCDIDATAFORMAT (WINAPI*)(); auto fn = reinterpret_cast<Fn>(Resolve("GetdfDIJoystick")); return fn ? fn() : nullptr;
}
