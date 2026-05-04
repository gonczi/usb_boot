# USB Boot - Alpine Linux Kiosk

Builds a bootable UEFI USB drive image from Alpine Linux that boots into a framebuffer kiosk mode displaying an image. The entire OS, kernel, and initramfs are packaged into a single Unified Kernel Image (UKI) — no bootloader configuration needed.

## How It Works

1. **Downloads** Alpine Linux minirootfs and packages (kernel, OpenSSH, fbi, graphics libs) from the official mirror
2. **Assembles** a custom initramfs with the rootfs, kernel modules, and an init script
3. **Creates a UKI** (`linux.efi`) containing the kernel + initramfs + boot cmdline via `ukify`
4. **Builds a GPT disk image** with an EFI System Partition containing the UKI as `BOOTX64.EFI`

At boot the init script sets up networking (DHCP), starts an SSH server (root/alpine), loads framebuffer drivers, and displays a kiosk image via `/dev/fb0`.

## Prerequisites

### System packages

Install all build dependencies (Debian/Ubuntu):

```sh
sudo apt install wget tar gzip cpio parted mtools make \
    systemd-ukify systemd-boot-efi python3-pefile \
    qemu-system-x86 ovmf
```

| Package              | apt package         | Used for                                  |
|----------------------|---------------------|-------------------------------------------|
| `wget`               | `wget`              | Downloading Alpine packages               |
| `tar`                | `tar`               | Extracting rootfs and APK archives        |
| `gzip`               | `gzip`              | Compressing initramfs                     |
| `cpio`               | `cpio`              | Creating initramfs cpio archive           |
| `make`               | `make`              | Build automation                          |
| `parted`             | `parted`            | Creating GPT partition table              |
| `mformat` / `mcopy`  | `mtools`            | Creating FAT32 filesystem on disk image   |
| `ukify`              | `systemd-ukify`     | Building Unified Kernel Image             |
| EFI stub             | `systemd-boot-efi`  | Provides `linuxx64.efi.stub` for ukify    |
| `python3-pefile`     | `python3-pefile`    | Python PE file library required by ukify  |
| `qemu-system-x86_64` | `qemu-system-x86`  | Testing the image in a VM                 |
| OVMF                 | `ovmf`              | UEFI firmware for QEMU                    |

KVM support (`/dev/kvm`) is recommended for usable VM performance.

### Kiosk image

Place the image to display at the root of the project:

```sh
cp your-image.png kiosk-image.png
```

This file must exist before running `make`. Supported formats: PNG, JPEG, BMP (anything `fbi` can display).

## Usage

```sh
make              # build everything (downloads ~100MB on first run)
make run          # test in QEMU (GTK window + serial on stdio)
```

SSH into the running VM:

```sh
ssh root@localhost -p 2222   # password: alpine
```

Write to a real USB drive:

```sh
sudo dd if=bootable-usb.img of=/dev/sdX bs=4M status=progress && sync
```

## Make Targets

| Target            | Description                             |
|-------------------|-----------------------------------------|
| `all` / `disk`    | Build the bootable disk image (default) |
| `download-alpine` | Download Alpine rootfs and packages     |
| `initramfs`       | Create the initramfs archive            |
| `uki`             | Create the Unified Kernel Image         |
| `run`             | Launch in QEMU                          |
| `clean`           | Remove all build artifacts              |

## Project Structure

- `init` — Boot init script (mounts filesystems, networking, SSH, kiosk display)
- `run.sh` — User script executed at the end of boot (customize for your use case)
- `kiosk-image.png` — Image displayed on the framebuffer (**required**, not tracked in git)
- `Makefile` — Full build pipeline
- `build/` — Build outputs (rootfs, initramfs, kernel, UKI)
- `build/tools/alpine-make-rootfs` — Downloaded helper script for building the Alpine rootfs

## Customization

### Boot script (`run.sh`)

`run.sh` is copied into `/root/run.sh` inside the initramfs and executed at the end of boot. Edit it to run any commands after the system is up (e.g. start a custom application, mount additional storage).

### Rootfs packages

Edit `ROOTFS_PACKAGES` in the `Makefile` to add or remove Alpine packages from the rootfs.

### Rootfs post-install script (`alpine-make-rootfs --script-chroot`)

The build uses [`alpine-make-rootfs`](https://github.com/alpinelinux/alpine-make-rootfs) to assemble the Alpine rootfs. You can pass a script with `--script-chroot` to run commands **inside a chroot of the freshly built rootfs** during the build — for example to configure services with `rc-update`, write config files, or run `apk` commands:

```sh
sudo alpine-make-rootfs --script-chroot --packages "openssh" ./build/alpine ./setup.sh
```

With `--script-chroot` the script runs as if it were running on the target Alpine system. Without it, the script runs on the host with `$ROOTFS` pointing to the rootfs directory.
