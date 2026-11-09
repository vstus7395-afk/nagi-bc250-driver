# Nagi BC-250 driver investigation

This repository tracks the Lineage II / D3D9-on-D3D12 investigation for the AMD BC-250 (gfx1013) and the Nagi WDDM driver.

## Current experimental change

- `patches/NAGI_GDI1_shared_open_fix.patch` — experimental compatibility patch for a narrowly validated GDI1 type-1 shared-texture allocation path when the resource-private record is absent.
- The patch is **not a released driver**. It has not yet been built with the Windows SDK/WDK or runtime-tested on BC-250 hardware.
- The patch must be applied to the matching upstream source revision: `amdgpu-wddm-0.7.216.109-tester.37`.

## Apply the patch

From the root of the matching source checkout:

```powershell
git apply .\patches\NAGI_GDI1_shared_open_fix.patch
```

Then build with the project's documented Windows toolchain and run the existing shared-surface tests before installing anything on the test machine.

## Important diagnostic context

The captured BC-250 log showed repeated `OpenHeapAndResource` failures for the L2.exe process: resource private data was 0 bytes while the first allocation private data was 48 bytes (LB7A v1 prefix). The driver logged E_INVALIDARG (0x80070057) but surfaced it as E_OUTOFMEMORY (0x8007000e). This is a lead, not proof that these failures alone cause the black window.

The proposed decoder accepts only a GDI1 type-1 texture record and constructs a copy-only resource description. Other GDI allocation types and nonzero flags are rejected. The actual GDI1 trailer fields must still be validated against the target driver build and runtime behavior.

## Source archive

The original source archive is not duplicated in this repository. Use the exact matching source package supplied separately; do not mix this patch with another Nagi revision.

## Safety

Do not install an unverified build as the only bootable driver. Preserve a known-good boot option and a recovery path before testing custom kernel drivers.
