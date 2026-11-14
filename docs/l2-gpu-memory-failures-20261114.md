# BC-250: two independent D3D allocation failures (2026-11-14)

Configuration reported by tester: AMD BC-250 integrated GPU, BIOS 2 GiB graphics aperture / UMA reservation, about 10 GiB free system RAM, Windows 11, 32-bit Lineage II High Five, amdgpu-wddm tester.37 with GDI shared-surface and BC250-HANGDIAG Release UMD patches.

## Case A — 20:55:25 local, indexed terrain render failure
Game dialog: `IDirect3DIndexBuffer9::Lock failed(8007000E)`; stack starts with `FD3DDynamicIndexBuffer::AddIndices`, then `ATerrainInfo::Render`.
Captured Win32 debug ring `BC250-LAST10MIN-20261114-205540.log` ending 20:55:40:
- 73 occurrences of `modern CORE CreateHeapAndResource: hr 8007000e, admitted 8007000e`, same L2 PID 10936.
- First visible at 20:51:56; rapid increase at 20:55:13-20:55:24 immediately preceding game error.
- Tester observed briefly flickering letters/digits rendered on game screen immediately before crash; this visual symptom does not prove VRAM exhaustion, descriptor corruption, nor a GPU reset.
- This log provides no Vulkan VkResult for `CreateHeapAndResource`; do not claim this path is the same failed operation as a descriptor heap.

## Case B — 22:41:55 local, fullscreen -> windowed Alt+Enter hang
Captured Win32 debug ring `BC250-LAST10MIN-20261114-224218.log` ending 22:42:18:
- 44 matched pairs, same L2 PID 11084, concentrated in ~18 ms.
- `vkd3d_allocate_device_memory: Failed to allocate device memory (size 64262272, type_flags 0x7, type_mask 0x2a).`
- `BC250-HANGDIAG descriptor_heap_failed type=0 count=1000000 ddi_flags=0x3 gpu_flags=0x1 hr=8007000e`.
- No more L2 PID output after 22:41:55.300 while another process continued to log.
- 64,262,272 bytes ~= 61.3 MiB requested for a shader-visible CBV/SRV/UAV descriptor heap. The 44 attempts must NOT be multiplied into 44 * resident memory; they all failed.

## Source inspection: required uncertainty
- In pinned D-Ogi/vkd3d-proton `libs/vkd3d/memory.c`, `vkd3d_try_allocate_device_memory` may return E_OUTOFMEMORY due to no compatible memory type, fixed ReBAR budget, or a failing Vulkan `vkAllocateMemory`. The public 8007000E log cannot distinguish them.
- In pinned amdgpu-wddm `engine-ddi/descriptors.cpp`, failure from `ID3D12Device::CreateDescriptorHeap` is returned without pretending success; `destroy_heap` drains replay then calls `Release()`. Merely seeing these code paths does not prove resources are freed at appropriate times or that there is a leak.
- 10 GiB of free OS RAM does not guarantee 10 GiB of free 32-bit process virtual address space or availability in a Vulkan memory type with the demanded flags. The 2 GiB BIOS setting is not a measurement of current Vulkan memory budget.

## Next test — strictly observational
Build a separate x86 UMD that adds diagnostic counters for successful large shader-visible heap creations, releases, current live heap-record count and peak. Record them at every failed heap creation. Compare live/made/freed values after a fresh launch and during an Alt+Enter failure. If live heap count rises monotonically and releases do not match, inspect ownership and lifetime before proposing a fix. If counts are low, investigate VkResult and budget in the vkd3d-proton engine / hosted Vulkan driver.

**Do not:** clamp the requested descriptor count below 1,000,000, fabricate success, forcibly release in-use heaps, change BIOS reservation or modify Windows protections without controlled evidence.

This branch is DIAGNOSTIC ONLY until runtime testing validates a root-cause fix.
