# usb_boot

This repository is an independent project for building a bootable USB image with framebuffer support. The focus here is on constructing a minimal Alpine-based UEFI disk image, packaging a custom initramfs, and testing the result in QEMU or on real hardware. There is no Tauri application in this tree.

## What this stage does

- Downloads Alpine 3.21 minirootfs and the LTS kernel package.
- Pulls in a small extra userspace set, including Midnight Commander and its runtime dependencies.
- Assembles a custom initramfs from the Alpine root filesystem.
- Generates a simple init script that mounts the core filesystems, runs `/root/run.sh`, and then drops to a root shell.
- Builds a Unified Kernel Image (`linux.efi`) with `ukify`.
- Creates a GPT/FAT32 UEFI-bootable disk image (`bootable-usb.img`) and places `BOOTX64.EFI` in the expected EFI path.
- Boots and tests the image in QEMU with serial-style `-nographic` output.
- Provides cleanup targets for build artifacts and cached Alpine packages.

## Current scope

This project focuses on the USB boot path and basic framebuffer-capable bootstrapping, not on a desktop or kiosk environment.

- The build pipeline is centered on Alpine rootfs, initramfs, UKI, and disk image generation.
- `run.sh` is a minimal boot-time script used to verify the boot path.

## Repository layout

- `Makefile` - build orchestration for downloading Alpine, creating the initramfs, building the UKI, and assembling the disk image.
- `run.sh` - script copied into the initramfs and executed during boot.
- `bootable-usb.img` - generated UEFI disk image.
- `build/` - generated kernel, initramfs, and UKI artifacts.
- `apk/` - cached Alpine packages used during the build.

## Build flow

The main targets in the `Makefile` are:

- `make download-alpine` - fetch Alpine rootfs, kernel, and the extra packages used in this stage.
- `make initramfs` - create the initramfs from the Alpine rootfs and generate the boot-time init script.
- `make uki` - build the Unified Kernel Image with `ukify`.
- `make disk` - create the GPT/FAT32 bootable disk image and copy `BOOTX64.EFI` into the EFI partition.
- `make run` - boot the generated image in QEMU.
- `make clean` - remove build artifacts while preserving the cached APK downloads.
- `make clean-apk` - remove the APK cache.
- `make clean-all` - remove both build artifacts and the APK cache.

The default target is `make`, which is equivalent to `make disk`.

## Expected output

After a successful build, the main artifact is:

- `bootable-usb.img`

Supporting files are written under `build/`, including the downloaded kernel, extracted Alpine rootfs, initramfs contents, and the final UKI image.

## Notes

The `run.sh` script is intentionally minimal. It exists to prove the boot path and confirm that the custom initramfs and UKI are working for the framebuffer boot image.