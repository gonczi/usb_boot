.PHONY: all clean clean-apk clean-all download-alpine initramfs uki disk run

# Configuration
ALPINE_VERSION := 3.21
ALPINE_ARCH := x86_64
ALPINE_MIRROR := https://dl-cdn.alpinelinux.org/alpine

# Directories
BUILD_DIR := build
APK_CACHE_DIR := apk
ALPINE_DIR := $(BUILD_DIR)/alpine
INITRAMFS_DIR := $(BUILD_DIR)/initramfs

# Output files
KERNEL_IMAGE := $(BUILD_DIR)/vmlinuz-lts
ALPINE_INITRAMFS := $(BUILD_DIR)/initramfs-alpine
INITRAMFS_CPIO := $(BUILD_DIR)/initramfs.cpio.gz
UKI_IMAGE := $(BUILD_DIR)/linux.efi
DISK_IMAGE := bootable-usb.img
DISK_SIZE_MB := 256

# Tools
UKIFY := ukify

all: disk

# Download Alpine Linux rootfs and kernel
$(KERNEL_IMAGE): 
	@echo "Downloading Alpine Linux $(ALPINE_VERSION) for $(ALPINE_ARCH)..."
	mkdir -p $(ALPINE_DIR) $(BUILD_DIR) $(APK_CACHE_DIR)
	@echo "Downloading Alpine minirootfs..."
	cd $(APK_CACHE_DIR) && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/releases/$(ALPINE_ARCH)/alpine-minirootfs-$(ALPINE_VERSION).0-$(ALPINE_ARCH).tar.gz
	cp $(APK_CACHE_DIR)/alpine-minirootfs-$(ALPINE_VERSION).0-$(ALPINE_ARCH).tar.gz $(ALPINE_DIR)/
	@echo "Extracting Alpine rootfs..."
	cd $(ALPINE_DIR) && \
		tar xzf alpine-minirootfs-$(ALPINE_VERSION).0-$(ALPINE_ARCH).tar.gz
	@echo "Downloading kernel package..."
	cd $(APK_CACHE_DIR) && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/linux-lts-6.12.65-r0.apk
	cp $(APK_CACHE_DIR)/linux-lts-6.12.65-r0.apk $(ALPINE_DIR)/
	@echo "Extracting kernel..."
	cd $(ALPINE_DIR) && \
		tar xzf linux-lts-6.12.65-r0.apk
	@echo "Downloading Midnight Commander..."
	cd $(APK_CACHE_DIR) && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/mc-4.8.32-r0.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/libssh2-1.11.1-r0.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/libncursesw-6.5_p20241006-r3.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/ncurses-terminfo-base-6.5_p20241006-r3.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/libintl-0.22.5-r0.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/glib-2.82.5-r0.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/slang-2.3.3-r3.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/gpm-libs-1.20.7-r5.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/e2fsprogs-libs-1.47.1-r1.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/gettext-libs-0.22.5-r0.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/pcre2-10.43-r0.apk
	cp $(APK_CACHE_DIR)/*.apk $(ALPINE_DIR)/
	@echo "Extracting Midnight Commander and dependencies..."
	cd $(ALPINE_DIR) && \
		tar xzf mc-4.8.32-r0.apk && \
		tar xzf libssh2-1.11.1-r0.apk && \
		tar xzf libncursesw-6.5_p20241006-r3.apk && \
		tar xzf ncurses-terminfo-base-6.5_p20241006-r3.apk && \
		tar xzf libintl-0.22.5-r0.apk && \
		tar xzf glib-2.82.5-r0.apk && \
		tar xzf slang-2.3.3-r3.apk && \
		tar xzf gpm-libs-1.20.7-r5.apk && \
		tar xzf e2fsprogs-libs-1.47.1-r1.apk && \
		tar xzf gettext-libs-0.22.5-r0.apk && \
		tar xzf pcre2-10.43-r0.apk
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
	# To reduce size, optionally exclude: --exclude='lib/firmware' --exclude='lib/modules'
	cd $(ALPINE_DIR) && tar cf - --exclude='*.apk' --exclude='alpine-minirootfs-*.tar.gz' \
		bin sbin lib lib64 usr etc 2>/dev/null | tar xf - -C ../../$(INITRAMFS_DIR)/ || true
	
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
	
	# Copy run.sh script
	cp run.sh $(INITRAMFS_DIR)/root/run.sh
	chmod +x $(INITRAMFS_DIR)/root/run.sh
	
	# Create init script
	@echo "Creating init script..."
	@echo '#!/bin/sh' > $(INITRAMFS_DIR)/init
	@echo '' >> $(INITRAMFS_DIR)/init
	@echo '# Mount essential filesystems' >> $(INITRAMFS_DIR)/init
	@echo 'mount -t proc none /proc' >> $(INITRAMFS_DIR)/init
	@echo 'mount -t sysfs none /sys' >> $(INITRAMFS_DIR)/init
	@echo 'mount -t devtmpfs none /dev' >> $(INITRAMFS_DIR)/init
	@echo '' >> $(INITRAMFS_DIR)/init
	@echo '# Clear screen' >> $(INITRAMFS_DIR)/init
	@echo 'clear' >> $(INITRAMFS_DIR)/init
	@echo '' >> $(INITRAMFS_DIR)/init
	@echo 'echo "======================================"' >> $(INITRAMFS_DIR)/init
	@echo 'echo "  Booting Custom Alpine Linux System "' >> $(INITRAMFS_DIR)/init
	@echo 'echo "======================================"' >> $(INITRAMFS_DIR)/init
	@echo 'echo ""' >> $(INITRAMFS_DIR)/init
	@echo '' >> $(INITRAMFS_DIR)/init
	@echo '# Execute run.sh script' >> $(INITRAMFS_DIR)/init
	@echo 'if [ -f /root/run.sh ]; then' >> $(INITRAMFS_DIR)/init
	@echo '    echo "Executing run.sh..."' >> $(INITRAMFS_DIR)/init
	@echo '    /root/run.sh' >> $(INITRAMFS_DIR)/init
	@echo '    echo ""' >> $(INITRAMFS_DIR)/init
	@echo 'fi' >> $(INITRAMFS_DIR)/init
	@echo '' >> $(INITRAMFS_DIR)/init
	@echo 'echo "Auto-login as root..."' >> $(INITRAMFS_DIR)/init
	@echo 'echo ""' >> $(INITRAMFS_DIR)/init
	@echo '' >> $(INITRAMFS_DIR)/init
	@echo '# Start shell as root' >> $(INITRAMFS_DIR)/init
	@echo 'exec /bin/sh' >> $(INITRAMFS_DIR)/init
	
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
	@echo "Creating $(DISK_SIZE_MB)MB disk image..."
	dd if=/dev/zero of=$(DISK_IMAGE) bs=1M count=$(DISK_SIZE_MB) status=progress
	
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
	@echo "  qemu-system-x86_64 -enable-kvm -m 512M -drive file=$(DISK_IMAGE),format=raw -bios /usr/share/ovmf/OVMF.fd"

disk: $(DISK_IMAGE)

# Run in QEMU
run: $(DISK_IMAGE)
	@echo "Starting QEMU..."
	@echo "Tip: To exit QEMU, press Ctrl+A then X"
	@echo ""
	qemu-system-x86_64 -enable-kvm -m 512M -drive file=bootable-usb.img,format=raw -bios /usr/share/ovmf/OVMF.fd -nographic

clean:
	@echo "Cleaning build directory..."
	rm -rf $(BUILD_DIR) $(DISK_IMAGE)
	rm -f build.log
	@echo "Clean complete."
	@echo "Note: APK cache preserved in $(APK_CACHE_DIR)/"

clean-apk:
	@echo "Cleaning APK cache..."
	rm -rf $(APK_CACHE_DIR)
	@echo "APK cache cleaned."

clean-all: clean clean-apk
	@echo "All build artifacts and cache cleaned."

help:
	@echo "Makefile targets:"
	@echo "  all             - Build everything and create disk image (default)"
	@echo "  download-alpine - Download Alpine Linux rootfs and kernel"
	@echo "  initramfs       - Create initramfs with run.sh"
	@echo "  uki             - Create Unified Kernel Image"
	@echo "  disk            - Create bootable disk image"
	@echo "  run             - Run the bootable disk image in QEMU"
	@echo "  clean           - Remove build artifacts (preserves APK cache)"
	@echo "  clean-apk       - Remove APK cache directory"
	@echo "  clean-all       - Remove all build artifacts and cache"
	@echo "  help            - Show this help message"
