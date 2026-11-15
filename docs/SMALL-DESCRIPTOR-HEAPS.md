# Smaller D3D9On12 descriptor heaps: experiment A

This is a behavior change through an existing release setting, not another logging DLL and not a proven hang fix. Keep the installed ALLOCDIAG v2 DLL and the GDI1/shared-surface fixes. No compilation or driver replacement is needed for this experiment.

Set `MaxSRVHeapSize=65536` in the 32-bit view of HKLM\Software\Microsoft\Direct3D\Direct3D9on12. This affects all newly started 32-bit D3D9On12 applications, not just L2. It does not change 64-bit applications' registry view. Close all game processes first. Run the script from an administrator Windows PowerShell. No reboot is required if all affected processes are restarted.

The script saves and verifies the previous value (including absence) under the actual Desktop folder, in BC250-heap-limit-backups. It changes only this DWORD. It neither replaces DLLs nor changes ACLs. `-Rollback` restores the latest backup; `-Rollback -BackupDirectory <folder>` selects one explicitly. A later conflicting value is not overwritten.

## Source basis

- Microsoft/D3D9On12 revision 9543ac633c8c73b31f6a630869bc769b89dbdebc, include/9on12Registry.h:9, 34-49, 106: the HKLM setting is read in release builds, with the process's default registry view.
- src/9on12Device.cpp:486: its value is passed to TranslationLayer's creation arguments.
- Microsoft/D3D12TranslationLayer revision 4b9c8f8a49c9b68df19be817d56f123d65704fd2, src/ImmediateContext.cpp:172-179: desktop starts with MaxSRVHeapSize descriptors, normally 1,000,000, rather than the Xbox growing ring-buffer path.
- ImmediateContext.cpp:552-643: rollover allocates/recycles heaps and refreshes bindings. The pool uses completed fences. The application asks for a smaller heap; the driver does not silently shrink a heap that the runtime requested.
- vkd3d-proton revision 507890134f8e3e1313d45f03c6bbe7ddde8bda7a, libs/vkd3d/resource.c:9546-9598: descriptor storage includes per-entry bytes and reserved metadata. Under the observed 64-byte layout, a 1,000,000-entry request is 64,262,272 bytes; 65,536 entries should require 4,456,576 bytes (about 4.25 MiB). This predicts one heap's size, not total process memory usage.

The installed Microsoft DLL may differ from these sources. Confirm the setting took effect: start the existing recorder before a fresh game process, then save the startup log with S. The installed UMD emits `descriptor_heap_large_ok` once per process; expect `count=65536`, not `count=1000000`. A heap limit saved in the registry alone does not prove that the loaded DLL honored it. If no marker is captured, inspect the loaded module and log before interpreting the test. Do not change BIOS memory, other registry settings, or driver versions at the same time.

## A/B check

1. Apply; start recorder and one fresh L2 process; save a startup log to confirm count=65536.
2. Exercise the same scene, fullscreen/windowed transitions and horizontal/vertical resize. Save immediately if the image freezes. Record the number of transitions and elapsed time.
3. Check for allocation failures and visual corruption. Smaller heaps can cause more rollover and affect performance; they do not guarantee lower peak memory if many remain in flight.
4. Roll back and repeat with the same conditions if practical. Confirm the previous descriptor count returns. Compare several runs, not just a single successful transition.

This tests whether the unusually large per-heap allocation contributes to the failure. It does not establish a leak, prove exhaustion of physical VRAM, fix all game allocator failures, or justify bypassing fences. If the parameter is honored but the same failure persists, investigate allocation residency/retirement and the TranslationLayer recovery sequence separately.
