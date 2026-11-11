# Shared-surface resize candidate

Base overlay: `90dbaa05abd963764a096adab61da37bdc7c6251` (BUILD29).
Upstream: `ec5326029afdc7950a2068ed5eece46a965b4eed`.

## Scope

The user reports freezes during both horizontal and vertical resize.
The older handoff's claim that horizontal resize is stable is superseded by that report.
The original full logs were not supplied with this task. The handoff contains excerpts only.
No hardware result is claimed for this candidate.

This cumulative patch keeps BUILD27's bare-allocation decoder and BUILD29's page-size correction.
It moves the layout decision into a tested contract helper.
It rejects zero sizes and overflow before rounding, and keeps exact pitch agreement.
It prints the first layout acceptance that needs page rounding, instead of printing every such acceptance.
Actual layout refusals retain their parameters, including engine memory size and alignment.
This preserves the shared DebugView message budget for later failures.

## Code review

At the pinned upstream revision, `driver/kmd/wddm.c` stores the logical private record unchanged.
It assigns `ROUND_TO_PAGES(private->Size)` to the allocation size given to VidMm.
`BC250_SHARED_SURFACE.Size` is 64-bit, including in the x86 UMD.
The decoder already checks overflow. The layout helper also checks it independently.

`query_linear_surface` includes both padded rows and the engine's memory requirement in its backing size.
The helper compares that entire backing with the physical page allocation.
It does not substitute visible pixel bytes or relax row pitch.
`adopt.byte_size` stays equal to the engine backing size and cannot exceed the checked allocation.
The existing adopt path checks alignment and maps only that requested size.
No allocation ownership, fence, presentation, or kernel code changes are included.

The tests cover exact pages, partial pages, insufficient backing, pitch mismatch, zero sizes, and integer boundaries.
They also sweep 2048 widths and 2048 heights using synthetic geometry.
These are arithmetic regression tests, not measurements of RADV or the BC-250.
The UINT32_MAX case checks the helper's arithmetic, not support for a 4 GiB image.

## Runtime procedure

Keep the original BUILD27 archive and its rollback DLL.
Install the candidate only after the user authorizes installation and confirms the rollback path.

1. Record the installed DLL hash and the candidate artifact's run ID.
2. Start DebugView before opening one Lineage II client.
3. Check ordinary windowed rendering before changing the window size.
4. Resize horizontally at a fixed height for up to 30 seconds.
5. Save that capture separately, with the starting and ending dimensions.
6. Restart the client before the next case.
7. Resize vertically at a fixed width for up to 30 seconds.
8. Save that capture separately, with the starting and ending dimensions.
9. Test diagonal resize in another fresh client session.
10. Repeat the same dimensions with the baseline, after an authorized rollback.

Stop the case immediately if rendering freezes or the display loses its signal.
Record whether the frame recovers after releasing the mouse.
Keep the window count and graphics settings equal between comparisons.
Use separate captures for each DLL version and each direction.

Search for `shared open: layout accepted (page rounding)` and `shared open: layout refused`.
The positive line appears at most once per process. Its absence does not prove failure.
It means the layout check accepted an allocation, not that the full import or frame presentation succeeded.
Also keep `OpenHeapAndResource`, `present copy`, and device-removal messages.

If freezes persist without layout refusals, investigate present-copy retirement, allocation lifetime, and synchronization next.
Do not weaken pitch or size validation to suppress an error.
Screenshot failures, shutdown crashes, projector hotplug, and 7RB artifacts remain separate unresolved reports.
