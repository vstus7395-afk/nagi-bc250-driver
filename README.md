# Nagi BC-250 driver investigation

This repository tracks the Lineage II / D3D9-on-D3D12 investigation for the AMD BC-250 (gfx1013) and the Nagi WDDM driver.

## Source and CI

- Upstream source: `D-Ogi/amdgpu-wddm@v0.7.216.109-tester.37`.
- `.github/workflows/import-source.yml` imports the full upstream source into `upstream-tester.37`, applies the experimental patch on `gdi1-experiment`, and compiles/runs the shared-surface contract test with x64 MSVC.
- See [source import and test notes](docs/SOURCE_IMPORT_AND_TEST.md).

## Current experimental change

- `patches/NAGI_GDI1_shared_open_fix.patch` — experimental compatibility patch for a narrowly validated GDI1 type-1 shared-texture allocation path when the resource-private record is absent.
- The patch is **not a released driver**. The focused contract test is not a complete D3D12 UMD/KMD build and is not runtime validation on BC-250 hardware.
- The patch is intended only for the exact tester.37 source revision.

## Apply the patch manually

From the root of the matching source checkout:

```powershell
git apply .\patches\NAGI_GDI1_shared_open_fix.patch
```

## Important diagnostic context

The captured BC-250 log showed repeated `OpenHeapAndResource` failures for the L2.exe process: resource private data was 0 bytes while the first allocation private data was 48 bytes (LB7A v1 prefix). The driver logged E_INVALIDARG (0x80070057) but surfaced it as E_OUTOFMEMORY (0x8007000e). This is a lead, not proof that these failures alone cause the black window.

The proposed decoder accepts only a GDI1 type-1 texture record and constructs a copy-only resource description. Other GDI allocation types and nonzero flags are rejected. The actual GDI1 trailer fields must still be validated against the target driver build and runtime behavior.

## Safety

Do not install an unverified build as the only bootable driver. Preserve a known-good boot option and a recovery path before testing custom kernel drivers.
