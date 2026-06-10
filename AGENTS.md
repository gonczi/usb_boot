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
- **Tauri runtime requirements** (beyond build deps):
  - `curl wget file` - networking/file utilities
  - `openssl` - SSL/TLS support
  - `libayatana-appindicator` - system tray functionality
  - `librsvg` - SVG rendering
  - `ttf-dejavu` - fonts (Alpine containers have no fonts by default)
  - Build-time only (`TAURI_BUILD_DEPS`): `build-base`, `webkit2gtk-4.1-dev`, etc.

## init Script Policy
- For VM-focused minimal graphics setup, load only generic modules:
  - `drm`, `drm_kms_helper`, `simpledrm`, `virtio_gpu`
- Do not load all vendor GPU drivers together (`i915`, `amdgpu`, `nouveau`) by default.
- **Essential tmpfs mounts for Wayland/wlroots**:
  - `/dev/shm` - required for shared memory (keymap, dmabuf)
  - `/run` - required for XDG_RUNTIME_DIR and sockets
  - `/tmp` - general temporary files
  - Without these, wlroots will fail with "Failed to allocate shm file" errors
- Runtime launch path is Wayland kiosk via `seatd` + `cage` + `/opt/kiosk/tauri_welcome`.

## Known Build Pitfalls
- `build/alpine` may be root-owned after privileged builds.
- Cleanup of `build/alpine` must handle privileged ownership, otherwise rebuild can fail with permission denied.
- Runtime package set changes can invalidate cached rootfs content (e.g. missing loader/theme assets). If so, remove `build/alpine` and `build/vmlinuz-lts` before rebuild.

## SSH/Boot Notes
- Root password auth is intentionally enabled for this kiosk/test image.
- If login fails, verify `/etc/shadow` exists in the assembled initramfs tree.

## Cage/Wlroots Environment Variables
- **XKB configuration**: All five XKB variables should be set explicitly:
  - `XKB_DEFAULT_RULES=evdev` (or `base`)
  - `XKB_DEFAULT_MODEL=pc105`
  - `XKB_DEFAULT_LAYOUT=us`
  - `XKB_DEFAULT_VARIANT=""`
  - `XKB_DEFAULT_OPTIONS=""`
- **Critical wlroots vars**:
  - `WLR_RENDERER_ALLOW_SOFTWARE=1` - enables software rendering (required for VMs)
  - `WLR_NO_HARDWARE_CURSORS=1` - uses software cursors
  - `LIBSEAT_BACKEND=seatd` - explicit seatd backend
  - **DO NOT use** `WLR_LIBINPUT_NO_DEVICES=1` - it masks real input device problems
- **Debug/logging**:
  - `cage -d` flag enables debug output
  - `LIBINPUT_LOG_PRIORITY=debug` for detailed libinput logs
- **Locale**: Set `LC_ALL=C` and `LANG=C` to avoid potential libxkbcommon locale issues
- **Reference docs**:
  - Cage config: https://github.com/cage-kiosk/cage/wiki/Configuration
  - Wlroots env vars: https://github.com/swaywm/wlroots/blob/master/docs/env_vars.md

## Documentation Sync Notes
- Keep `README.md` aligned with current runtime behavior: Wayland/cage/Tauri (not framebuffer/fbi flow).
- `kiosk-image.png` is still a required build input because it is copied into initramfs, even though the active kiosk UI is the Tauri app.

## Updating This File
- Keep entries short and actionable.
- Update when package names, build targets, or boot/init behavior changes.
