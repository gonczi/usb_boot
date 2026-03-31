# USB Boot - Alpine Linux Kiosk

Builds a bootable UEFI USB drive image from Alpine Linux that boots into a framebuffer kiosk mode displaying an image. The entire OS, kernel, and initramfs are packaged into a single Unified Kernel Image (UKI) — no bootloader configuration needed.

## How It Works

1. **Downloads** Alpine Linux minirootfs and packages (kernel, OpenSSH, fbi, graphics libs) from the official mirror
2. **Assembles** a custom initramfs with the rootfs, kernel modules, and an init script
3. **Creates a UKI** (`linux.efi`) containing the kernel + initramfs + boot cmdline via `ukify`
4. **Builds a GPT disk image** with an EFI System Partition containing the UKI as `BOOTX64.EFI`

At boot the init script sets up networking (DHCP), starts an SSH server (root/alpine), loads framebuffer drivers, and displays a kiosk image via `/dev/fb0`.

## Prerequisites

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

| Target             | Description                                  |
|--------------------|----------------------------------------------|
| `all` / `disk`     | Build the bootable disk image (default)      |
| `download-alpine`  | Download Alpine rootfs and packages          |
| `initramfs`        | Create the initramfs archive                 |
| `uki`              | Create the Unified Kernel Image              |
| `run`              | Launch in QEMU                               |
| `clean`            | Remove build artifacts (keeps APK cache)     |
| `clean-all`        | Remove everything including cached downloads |

## Project Structure

- `init` — Boot init script (mounts filesystems, networking, SSH, kiosk display)
- `run.sh` — User script executed during boot
- `Makefile` — Full build pipeline
- `apk/` — Cached APK packages and version metadata
- `build/` — Build outputs (rootfs, initramfs, kernel, UKI)
