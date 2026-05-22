.PHONY: all clean clean-all download-alpine initramfs uki disk repack run

# Configuration
ALPINE_VERSION := 3.21
ALPINE_ARCH := x86_64
ALPINE_MIRROR := https://dl-cdn.alpinelinux.org/alpine

# Directories
BUILD_DIR := build
TOOLS_DIR := $(BUILD_DIR)/tools
ALPINE_DIR := $(BUILD_DIR)/alpine
INITRAMFS_DIR := $(BUILD_DIR)/initramfs

# Output files
KERNEL_IMAGE := $(BUILD_DIR)/vmlinuz-lts
ALPINE_INITRAMFS := $(BUILD_DIR)/initramfs-alpine
INITRAMFS_CPIO := $(BUILD_DIR)/initramfs.cpio.gz
UKI_IMAGE := $(BUILD_DIR)/linux.efi
DISK_IMAGE := bootable-usb.img
DISK_MIN_SIZE_MB := 256
DISK_PADDING_MB := 128

# Tools
UKIFY := ukify
ALPINE_MAKE_ROOTFS_VERSION := v0.8.1
ALPINE_MAKE_ROOTFS := $(TOOLS_DIR)/alpine-make-rootfs

# Packages installed into the rootfs; dependencies are resolved automatically by apk.
ROOTFS_PACKAGES := linux-lts openssh openssh-server-common openssh-sftp-server

all: disk



# Download Alpine Linux rootfs and kernel
$(KERNEL_IMAGE): 
	@echo "Preparing alpine-make-rootfs $(ALPINE_MAKE_ROOTFS_VERSION)..."
	mkdir -p $(BUILD_DIR) $(TOOLS_DIR)
	@if [ ! -x $(ALPINE_MAKE_ROOTFS) ]; then \
		wget -q -O $(ALPINE_MAKE_ROOTFS) https://raw.githubusercontent.com/alpinelinux/alpine-make-rootfs/$(ALPINE_MAKE_ROOTFS_VERSION)/alpine-make-rootfs && \
		chmod +x $(ALPINE_MAKE_ROOTFS); \
	fi

	@echo "Building Alpine rootfs with apk dependency resolution..."
	rm -rf $(ALPINE_DIR)
	@SUDO=""; \
	if [ "$$(id -u)" -ne 0 ]; then SUDO="sudo"; fi; \
	APK_OPTS="--no-progress --arch $(ALPINE_ARCH)" \
		$$SUDO $(ALPINE_MAKE_ROOTFS) \
		--branch v$(ALPINE_VERSION) \
		--mirror-uri $(ALPINE_MIRROR) \
		--packages "$(ROOTFS_PACKAGES)" \
		$(ALPINE_DIR)

	@echo "Copying kernel to build directory..."
	cp $(ALPINE_DIR)/boot/vmlinuz-lts $(KERNEL_IMAGE)
	@echo "Kernel ready at $(KERNEL_IMAGE)"

download-alpine: $(KERNEL_IMAGE)

# Create initramfs
$(INITRAMFS_CPIO): $(KERNEL_IMAGE)
	@echo "Creating initramfs from Alpine Linux..."
	rm -rf $(INITRAMFS_DIR)
	mkdir -p $(INITRAMFS_DIR)
	
	# Copy Alpine rootfs
	@echo "Copying Alpine rootfs..."
	@SUDO=""; \
	if [ "$$(id -u)" -ne 0 ]; then SUDO="sudo"; fi; \
	cd $(ALPINE_DIR) && \
		$$SUDO tar cf - --exclude='*.apk' --exclude='alpine-minirootfs-*.tar.gz' \
		--exclude='lib/firmware' --exclude='lib/firmware/*' \
		bin sbin lib lib64 usr etc 2>/dev/null | tar xf - -C ../../$(INITRAMFS_DIR)/
	@test -f $(INITRAMFS_DIR)/etc/shadow || (echo "ERROR: $(INITRAMFS_DIR)/etc/shadow is missing (root auth will fail). Rebuild with proper sudo access." && exit 1)
	
	# Create directory structure
	mkdir -p $(INITRAMFS_DIR)/dev
	mkdir -p $(INITRAMFS_DIR)/proc
	mkdir -p $(INITRAMFS_DIR)/sys
	mkdir -p $(INITRAMFS_DIR)/root
	mkdir -p $(INITRAMFS_DIR)/tmp
	mkdir -p $(INITRAMFS_DIR)/mnt
	mkdir -p $(INITRAMFS_DIR)/run
	
	# Note: Device nodes are not created here; devtmpfs will handle them at boot
	# The init script mounts devtmpfs which automatically creates device nodes
	
	# Copy kiosk image
	@echo "Copying kiosk image..."
	cp kiosk-image.png $(INITRAMFS_DIR)/root/kiosk-image.png
	
	# Copy init script
	@echo "Copying init script..."
	cp init $(INITRAMFS_DIR)/init
	chmod +x $(INITRAMFS_DIR)/init
	
	# Create initramfs archive
	@echo "Creating initramfs archive..."
	cd $(INITRAMFS_DIR) && \
		find . | cpio -H newc -o | gzip > ../initramfs.cpio.gz
	
	@echo "Initramfs created: $(INITRAMFS_CPIO)"

initramfs: $(INITRAMFS_CPIO)

# Create UKI using ukify
$(UKI_IMAGE): $(KERNEL_IMAGE) $(INITRAMFS_CPIO)
	@echo "Creating Unified Kernel Image (UKI)..."
	$(UKIFY) build \
		--linux=$(KERNEL_IMAGE) \
		--initrd=$(INITRAMFS_CPIO) \
		--cmdline="console=tty0 console=ttyS0 earlyprintk=serial,ttyS0,115200 loglevel=7 debug" \
		--output=$(UKI_IMAGE)
	@echo "UKI created: $(UKI_IMAGE)"

uki: $(UKI_IMAGE)

# Create bootable disk image
$(DISK_IMAGE): $(UKI_IMAGE)
	@echo "Creating bootable disk image..."
	
	# Create empty disk image
	@UKI_SIZE_MB=$$(( ($$(stat -c%s $(UKI_IMAGE)) + 1048575) / 1048576 )); \
	DISK_SIZE_MB=$$(( $$UKI_SIZE_MB + $(DISK_PADDING_MB) )); \
	if [ $$DISK_SIZE_MB -lt $(DISK_MIN_SIZE_MB) ]; then DISK_SIZE_MB=$(DISK_MIN_SIZE_MB); fi; \
	echo "Creating $$DISK_SIZE_MB MB disk image (UKI $$UKI_SIZE_MB MB + $(DISK_PADDING_MB) MB padding)..."; \
	dd if=/dev/zero of=$(DISK_IMAGE) bs=1M count=$$DISK_SIZE_MB status=progress
	
	# Create GPT partition table and EFI system partition
	@echo "Creating GPT partition table..."
	parted -s $(DISK_IMAGE) mklabel gpt
	parted -s $(DISK_IMAGE) mkpart primary fat32 1MiB 100%
	parted -s $(DISK_IMAGE) set 1 esp on
	
	# Format the partition using mformat (mtools)
	@echo "Creating FAT32 filesystem using mtools..."
	@PART_OFFSET=$$(parted -s $(DISK_IMAGE) unit B print | grep '^ 1' | awk '{print $$2}' | sed 's/B//'); \
	echo "Partition offset: $$PART_OFFSET bytes"; \
	mformat -i $(DISK_IMAGE)@@$$PART_OFFSET -F -v EFIBOOT ::
	
	# Create directory structure and copy files using mtools
	@echo "Creating EFI directory structure..."
	@PART_OFFSET=$$(parted -s $(DISK_IMAGE) unit B print | grep '^ 1' | awk '{print $$2}' | sed 's/B//'); \
	mmd -i $(DISK_IMAGE)@@$$PART_OFFSET ::/EFI; \
	mmd -i $(DISK_IMAGE)@@$$PART_OFFSET ::/EFI/BOOT; \
	echo "Copying UKI to EFI partition..."; \
	mcopy -i $(DISK_IMAGE)@@$$PART_OFFSET $(UKI_IMAGE) ::/EFI/BOOT/BOOTX64.EFI
	
	@echo "=========================================="
	@echo "Bootable disk image created: $(DISK_IMAGE)"
	@echo "=========================================="
	@echo "To write to USB drive:"
	@echo "  sudo dd if=$(DISK_IMAGE) of=/dev/sdX bs=4M status=progress && sync"
	@echo "  (Replace /dev/sdX with your USB drive)"
	@echo ""
	@echo "To test in QEMU:"
	@echo "  qemu-system-x86_64 -enable-kvm -m 2G -drive file=$(DISK_IMAGE),format=raw -bios /usr/share/ovmf/OVMF.fd"

disk: $(DISK_IMAGE)

repack:
	@echo "Repacking from cached Alpine rootfs..."
	rm -f $(INITRAMFS_CPIO) $(UKI_IMAGE) $(DISK_IMAGE)
	$(MAKE) disk

# Run in QEMU
run: $(DISK_IMAGE)
	@echo "Starting QEMU..."
	@echo "Window will show system console, terminal shows kernel logs"
	@echo "SSH access: ssh root@localhost -p 2222 (password: alpine)"
	@echo "Tip: To exit QEMU, close the window or press Ctrl+C in terminal"
	@echo ""
	qemu-system-x86_64 -enable-kvm -m 2G \
		-drive file=bootable-usb.img,format=raw \
		-bios /usr/share/ovmf/OVMF.fd \
		-vga std \
		-display gtk \
		-serial stdio \
		-netdev user,id=net0,hostfwd=tcp::2222-:22 \
		-device e1000,netdev=net0

clean:
	@echo "Cleaning build directory..."
	rm -rf $(BUILD_DIR) $(DISK_IMAGE)
	rm -f build.log
	@echo "Clean complete."

help:
	@echo "Makefile targets:"
	@echo "  all             - Build everything and create bootable disk image (default)"
	@echo "  download-alpine - Download Alpine Linux rootfs and kernel"
	@echo "  initramfs       - Create initramfs"
	@echo "  uki             - Create Unified Kernel Image"
	@echo "  disk            - Create bootable disk image"
	@echo "  repack          - Rebuild disk image from cached Alpine rootfs"
	@echo "  run             - Run in QEMU (window + console logs)"
	@echo "  clean           - Remove build artifacts"
	@echo "  help            - Show this help message"
