# Allocation failure diagnostics, 2026-11-14

This is a test candidate, not a confirmed fix for the Lineage II hang.

## Evidence and limits

The 22:41 capture contains 44 paired failures from one process/thread:
`vkd3d_allocate_device_memory(size=64262272, flags=0x7, mask=0x2a)`
and `descriptor_heap_failed(type=0, count=1000000, hr=8007000e)`.
The 20:52 capture has 73 `CreateHeapAndResource` failures, extending to
20:55. It does not identify the source of the reported flickering glyphs.
Neither capture contains the first failing hosted callback or CPU VA data.
Free system RAM does not establish available process VA, GPU VA, or residency.

## Changes

The descriptor creation path now returns D3DDDIERR_DEVICEREMOVED when the
shell has already latched device loss, including a loss during a failed engine
create. It does not infer loss from OOM. For a live device the original error
and requested descriptor count are unchanged. This closes a missing loss check;
the captures do not prove that this condition caused the observed hang.

The `BC250-ALLOCDIAG v=2` channel records descriptor request IDs, raw hosted
callback failures before HRESULT-to-status conversion, failed GPU VA ranges,
residency trim requirements and resource descriptions. IDs correlate synchronous
callbacks on the same thread, not work deferred to another thread.

The previous 512-events-per-process diagnostic quota is replaced with independent
64-events-per-minute quotas for command, descriptor, resource, hosted, snapshot
and large-descriptor-begin events. Each quota emits one suppression marker and
renews. Common shared-surface messages cannot consume these quotas.

On the first failed create each minute, the module samples process free VA,
largest free region, committed/reserved VA and GlobalMemoryStatusEx. The scan
uses stack storage, is not an atomic snapshot and can change timing. A zero
`va_complete` means the walk stopped early. `commit_available` is
GlobalMemoryStatusEx.ullAvailPageFile, not a GPU budget or installed RAM size.

GDI1 decoding, page rounding, pitches, GPU fences, residency policy and memory
placement are unchanged. The build replaces only the x86 D3D12 UMD; it does not
rebuild VKD3D or RADV. It therefore cannot expose Vulkan-side failures that occur
before any hosted callback. A hang dump and module identities remain useful.

## Exact base and application

Overlay base: cb0bdb519140f27117ab651a64971c50eabba740.
Upstream: D-Ogi/amdgpu-wddm ec5326029afdc7950a2068ed5eece46a965b4eed.
Apply these patches in order to a clean upstream checkout:

1. NAGI_GDI1_shared_open_fix.patch from the overlay base.
2. BC250_L2_HANGDIAG.patch from the overlay base.
3. BC250_ALLOCATION_DIAG_V2.patch from this change.

Run `git apply --check` before each application. The existing x86 workflow pins
the toolchain and headers. It builds the release UMD, runs native x86 policy
and shared-surface contract tests, then packages the DLL, symbols and patch.
No installer is bundled: the old installer writes backups inside DriverStore
and previously failed with access denied. No automatic installation is performed.

## Validation and interpretation

The portable policy test covers 600 quota renewals, late timestamps, eight
concurrent callers, separate budgets and loss classification. CI also compiles
the complete x86 DLL and runs the shared-surface contract tests. None of these
tests establishes that the original game hang is fixed on hardware.

Capture Win32 OutputDebugString without excluding BC250-ALLOCDIAG. Verify
`channel_ready` with `v=2` after a fresh game process starts. Capture only one
mode transition first. Preserve the first `descriptor_begin`, all `hosted_failed`
events, `descriptor_failed`, `cpu_memory`, and any command-list failures. Save
a full hang dump and the loaded-module paths, versions and hashes. Do not change
BIOS memory or disable synchronization during this comparison.

If hosted failures identify MapGpuVirtualAddress, inspect GPU VA ownership and
deferred BO retirement. If they identify MakeResident, inspect the reported trim
and budgets. If no hosted failure appears, inspect Vulkan memory type selection,
RADV allocation bookkeeping and CPU metadata allocation using the actual DLL
revision. A small largest-free CPU range supports fragmentation but does not by
itself prove that the failing GPU request needed that CPU range.
