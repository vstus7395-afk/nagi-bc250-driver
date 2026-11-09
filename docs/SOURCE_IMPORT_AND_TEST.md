# Source import and GDI1 test

The source release used by this investigation is the public Nagi tag
`D-Ogi/amdgpu-wddm@v0.7.216.109-tester.37`. Its source is already published by the upstream project. The
workflow in `.github/workflows/import-source.yml` imports that exact tag into this repository, so the complete
source tree is available here without asking a developer to upload a large ZIP through the browser.

After a successful workflow run, this repository has two source branches:

- `upstream-tester.37`: unmodified source at the exact upstream tester.37 tag.
- `gdi1-experiment`: the same source with `patches/NAGI_GDI1_shared_open_fix.patch` applied.

The workflow then compiles and runs `driver/contract/test/shared-surface-test.cpp` with x64 MSVC on
Windows Server 2022.

## What this build does not prove

This is a focused contract-test build. It is not the complete D3D12 UMD, KMD, installer or signed driver package.
The changed `resources.cpp` translation unit and the complete 32-bit and 64-bit UMD pair still need the full
project build described in upstream `docs/build.md`, including the pinned SDK/WDK, engine and Mesa/Vulkan
headers. No driver binary from this workflow is safe or suitable to install on the BC-250.

## Next validation

1. Open the repository's Actions tab and inspect **Import Nagi source and build GDI1 test**.
2. Confirm that both source branches exist and that the MSVC contract test passes.
3. Only after that, extend CI to the full D3D12 UMD build and package validation.
4. Install nothing until the full build succeeds and the test package has a known signing and rollback path.

The upstream source is under PolyForm Noncommercial 1.0.0. Keep `LICENSE.md`, `NOTICE` and all third-party
license notices with every redistributed copy. This repository is for noncommercial research and testing.
