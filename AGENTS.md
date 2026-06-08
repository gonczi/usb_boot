# AGENTS.md

Project-level agent notes for usb_boot.

## Scope
- This file defines repository-specific guidance for coding agents working in this project.
- Keep global/personal preferences outside this file.

## Build Flow
- Primary targets: `make download-alpine`, `make initramfs`, `make uki`, `make disk`, `make run`.
- Fast rebuild from cached rootfs: `make repack`.
- Typical full local test: `sudo make run`.
- Most build paths are expected to run with sudo because cached trees can become root-owned.

## Rootfs Package Policy
- Alpine branch is v3.21.
- WebKitGTK package name is versioned: use `webkit2gtk-4.1` (not `webkit2gtk`).
- Keep the runtime minimal for Tauri on Wayland.

## init Script Policy
- For VM-focused minimal graphics setup, load only generic modules:
  - `drm`, `drm_kms_helper`, `simpledrm`, `virtio_gpu`
- Do not load all vendor GPU drivers together (`i915`, `amdgpu`, `nouveau`) by default.
- Runtime launch path is Wayland kiosk via `seatd` + `cage` + `/opt/kiosk/tauri_welcome`.

## Known Build Pitfalls
- `build/alpine` may be root-owned after privileged builds.
- Cleanup of `build/alpine` must handle privileged ownership, otherwise rebuild can fail with permission denied.
- Runtime package set changes can invalidate cached rootfs content (e.g. missing loader/theme assets). If so, remove `build/alpine` and `build/vmlinuz-lts` before rebuild.

## SSH/Boot Notes
- Root password auth is intentionally enabled for this kiosk/test image.
- If login fails, verify `/etc/shadow` exists in the assembled initramfs tree.

## Documentation Sync Notes
- Keep `README.md` aligned with current runtime behavior: Wayland/cage/Tauri (not framebuffer/fbi flow).
- `kiosk-image.png` is still a required build input because it is copied into initramfs, even though the active kiosk UI is the Tauri app.

## Updating This File
- Keep entries short and actionable.
- Update when package names, build targets, or boot/init behavior changes.
