# BD-253 x86 D3D12 UMD test build

This is a reversible **user-mode-only** test of the D3D9On12 shared-allocation decoder on the exact Nagi `tester.37` source.

It replaces only the registered 32-bit D3D12 UMD DLL. It does not replace the KMD, INF, catalog, Vulkan ICD, or 64-bit UMD.

## Install

1. Close Lineage II and other 32-bit D3D12 applications.
2. Extract the GitHub Actions artifact ZIP.
3. Put `install-bd253-test-umd.ps1` beside `amdgpu_wddm_d3d12.dll`.
4. Open PowerShell as Administrator in that folder and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install-bd253-test-umd.ps1
```

The script finds the registered `UserModeDriverNameWow` D3D12 DLL, makes a timestamped backup beside it, copies the test DLL, and verifies SHA-256.

## Roll back

Run:

```powershell
.\install-bd253-test-umd.ps1 -Rollback
```

It restores the newest timestamped BD-253 backup. If Windows refuses to overwrite a file because it is in use, reboot and run the script again before launching the game.

**Scope:** this is an experimental x86 UMD replacement, not a complete signed driver package. The existing kernel driver remains untouched.
