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
	
	@echo "Downloading package indexes..."
	@cd $(APK_CACHE_DIR) && \
		wget -q -O APKINDEX-main.tar.gz $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/APKINDEX.tar.gz && \
		wget -q -O APKINDEX-community.tar.gz $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/community/$(ALPINE_ARCH)/APKINDEX.tar.gz
	
	@echo "Discovering latest package versions..."
	@cd $(APK_CACHE_DIR) && \
		echo "#!/bin/sh" > get_version.sh && \
		echo 'tar -xzOf $$1 APKINDEX | grep -A1 "^P:$$2$$" | grep "^V:" | head -1 | cut -d: -f2' >> get_version.sh && \
		chmod +x get_version.sh && \
		KERNEL_VER=$$(./get_version.sh APKINDEX-main.tar.gz linux-lts) && \
		FBI_VER=$$(./get_version.sh APKINDEX-community.tar.gz fbida-fbi) && \
		GIFLIB_VER=$$(./get_version.sh APKINDEX-main.tar.gz giflib) && \
		FONTCONFIG_VER=$$(./get_version.sh APKINDEX-main.tar.gz fontconfig) && \
		FREETYPE_VER=$$(./get_version.sh APKINDEX-main.tar.gz freetype) && \
		LIBDRM_VER=$$(./get_version.sh APKINDEX-main.tar.gz libdrm) && \
		LIBEXIF_VER=$$(./get_version.sh APKINDEX-community.tar.gz libexif) && \
		TIFF_VER=$$(./get_version.sh APKINDEX-main.tar.gz tiff) && \
		PIXMAN_VER=$$(./get_version.sh APKINDEX-main.tar.gz pixman) && \
		LIBWEBP_VER=$$(./get_version.sh APKINDEX-main.tar.gz libwebp) && \
		LIBPNG_VER=$$(./get_version.sh APKINDEX-main.tar.gz libpng) && \
		LIBJPEG_VER=$$(./get_version.sh APKINDEX-main.tar.gz libjpeg-turbo) && \
		LIBEXPAT_VER=$$(./get_version.sh APKINDEX-main.tar.gz libexpat) && \
		LIBBZ2_VER=$$(./get_version.sh APKINDEX-main.tar.gz libbz2) && \
		BROTLI_VER=$$(./get_version.sh APKINDEX-main.tar.gz brotli-libs) && \
		ZSTD_VER=$$(./get_version.sh APKINDEX-main.tar.gz zstd-libs) && \
		SHARPYUV_VER=$$(./get_version.sh APKINDEX-main.tar.gz libsharpyuv) && \
		FONT_DEJAVU_VER=$$(./get_version.sh APKINDEX-main.tar.gz font-dejavu) && \
		OPENSSH_VER=$$(./get_version.sh APKINDEX-main.tar.gz openssh) && \
		OPENSSH_SERVER_VER=$$(./get_version.sh APKINDEX-main.tar.gz openssh-server-common) && \
		OPENSSH_SFTP_VER=$$(./get_version.sh APKINDEX-main.tar.gz openssh-sftp-server) && \
		LIBCRYPTO_VER=$$(./get_version.sh APKINDEX-main.tar.gz libcrypto3) && \
		LIBSSL_VER=$$(./get_version.sh APKINDEX-main.tar.gz libssl3) && \
		ZLIB_VER=$$(./get_version.sh APKINDEX-main.tar.gz zlib) && \
		KRBC_VER=$$(./get_version.sh APKINDEX-main.tar.gz krb5-libs) && \
		echo "KERNEL_VER=$$KERNEL_VER" > versions.env && \
		echo "FBI_VER=$$FBI_VER" >> versions.env && \
		echo "GIFLIB_VER=$$GIFLIB_VER" >> versions.env && \
		echo "FONTCONFIG_VER=$$FONTCONFIG_VER" >> versions.env && \
		echo "FREETYPE_VER=$$FREETYPE_VER" >> versions.env && \
		echo "LIBDRM_VER=$$LIBDRM_VER" >> versions.env && \
		echo "LIBEXIF_VER=$$LIBEXIF_VER" >> versions.env && \
		echo "TIFF_VER=$$TIFF_VER" >> versions.env && \
		echo "PIXMAN_VER=$$PIXMAN_VER" >> versions.env && \
		echo "LIBWEBP_VER=$$LIBWEBP_VER" >> versions.env && \
		echo "LIBPNG_VER=$$LIBPNG_VER" >> versions.env && \
		echo "LIBJPEG_VER=$$LIBJPEG_VER" >> versions.env && \
		echo "LIBEXPAT_VER=$$LIBEXPAT_VER" >> versions.env && \
		echo "LIBBZ2_VER=$$LIBBZ2_VER" >> versions.env && \
		echo "BROTLI_VER=$$BROTLI_VER" >> versions.env && \
		echo "ZSTD_VER=$$ZSTD_VER" >> versions.env && \
		echo "SHARPYUV_VER=$$SHARPYUV_VER" >> versions.env && \
		echo "FONT_DEJAVU_VER=$$FONT_DEJAVU_VER" >> versions.env && \
		echo "OPENSSH_VER=$$OPENSSH_VER" >> versions.env && \
		echo "OPENSSH_SERVER_VER=$$OPENSSH_SERVER_VER" >> versions.env && \
		echo "OPENSSH_SFTP_VER=$$OPENSSH_SFTP_VER" >> versions.env && \
		echo "LIBCRYPTO_VER=$$LIBCRYPTO_VER" >> versions.env && \
		echo "LIBSSL_VER=$$LIBSSL_VER" >> versions.env && \
		echo "ZLIB_VER=$$ZLIB_VER" >> versions.env && \
		echo "KRBC_VER=$$KRBC_VER" >> versions.env && \
		cat versions.env
	
	@echo "Downloading Alpine minirootfs..."
	cd $(APK_CACHE_DIR) && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/releases/$(ALPINE_ARCH)/alpine-minirootfs-$(ALPINE_VERSION).0-$(ALPINE_ARCH).tar.gz
	cp $(APK_CACHE_DIR)/alpine-minirootfs-$(ALPINE_VERSION).0-$(ALPINE_ARCH).tar.gz $(ALPINE_DIR)/
	@echo "Extracting Alpine rootfs..."
	cd $(ALPINE_DIR) && \
		tar xzf alpine-minirootfs-$(ALPINE_VERSION).0-$(ALPINE_ARCH).tar.gz
	
	@echo "Downloading packages with discovered versions..."
	@cd $(APK_CACHE_DIR) && \
		. ./versions.env && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/linux-lts-$$KERNEL_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/community/$(ALPINE_ARCH)/fbida-fbi-$$FBI_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/giflib-$$GIFLIB_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/fontconfig-$$FONTCONFIG_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/freetype-$$FREETYPE_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/libdrm-$$LIBDRM_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/community/$(ALPINE_ARCH)/libexif-$$LIBEXIF_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/tiff-$$TIFF_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/pixman-$$PIXMAN_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/libwebp-$$LIBWEBP_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/libpng-$$LIBPNG_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/libjpeg-turbo-$$LIBJPEG_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/libexpat-$$LIBEXPAT_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/libbz2-$$LIBBZ2_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/brotli-libs-$$BROTLI_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/zstd-libs-$$ZSTD_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/libsharpyuv-$$SHARPYUV_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/font-dejavu-$$FONT_DEJAVU_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/openssh-$$OPENSSH_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/openssh-server-common-$$OPENSSH_SERVER_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/openssh-sftp-server-$$OPENSSH_SFTP_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/libcrypto3-$$LIBCRYPTO_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/libssl3-$$LIBSSL_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/zlib-$$ZLIB_VER.apk && \
		wget -c $(ALPINE_MIRROR)/v$(ALPINE_VERSION)/main/$(ALPINE_ARCH)/krb5-libs-$$KRBC_VER.apk
	
	@echo "Copying packages to Alpine directory..."
	cp $(APK_CACHE_DIR)/*.apk $(ALPINE_DIR)/
	
	@echo "Extracting packages..."
	@cd $(ALPINE_DIR) && \
		. ../../$(APK_CACHE_DIR)/versions.env && \
		tar xzf linux-lts-$$KERNEL_VER.apk && \
		tar xzf fbida-fbi-$$FBI_VER.apk && \
		tar xzf giflib-$$GIFLIB_VER.apk && \
		tar xzf fontconfig-$$FONTCONFIG_VER.apk && \
		tar xzf freetype-$$FREETYPE_VER.apk && \
		tar xzf libdrm-$$LIBDRM_VER.apk && \
		tar xzf libexif-$$LIBEXIF_VER.apk && \
		tar xzf tiff-$$TIFF_VER.apk && \
		tar xzf pixman-$$PIXMAN_VER.apk && \
		tar xzf libwebp-$$LIBWEBP_VER.apk && \
		tar xzf libpng-$$LIBPNG_VER.apk && \
		tar xzf libjpeg-turbo-$$LIBJPEG_VER.apk && \
		tar xzf libexpat-$$LIBEXPAT_VER.apk && \
		tar xzf libbz2-$$LIBBZ2_VER.apk && \
		tar xzf brotli-libs-$$BROTLI_VER.apk && \
		tar xzf zstd-libs-$$ZSTD_VER.apk && \
		tar xzf libsharpyuv-$$SHARPYUV_VER.apk && \
		tar xzf font-dejavu-$$FONT_DEJAVU_VER.apk && \
		tar xzf openssh-$$OPENSSH_VER.apk && \
		tar xzf openssh-server-common-$$OPENSSH_SERVER_VER.apk && \
		tar xzf openssh-sftp-server-$$OPENSSH_SFTP_VER.apk && \
		tar xzf libcrypto3-$$LIBCRYPTO_VER.apk && \
		tar xzf libssl3-$$LIBSSL_VER.apk && \
		tar xzf zlib-$$ZLIB_VER.apk && \
		tar xzf krb5-libs-$$KRBC_VER.apk
	
	@echo "Copying kernel to build directory..."
	cp $(ALPINE_DIR)/boot/vmlinuz-lts $(KERNEL_IMAGE)
	@echo "Kernel ready at $(KERNEL_IMAGE)"

download-alpine: $(KERNEL_IMAGE)

# Ensure packages are extracted into alpine directory
.PHONY: extract-packages
extract-packages:
	@if [ ! -f $(ALPINE_DIR)/usr/sbin/sshd ]; then \
		if [ -f $(APK_CACHE_DIR)/openssh-*.apk ]; then \
			echo "Extracting packages into Alpine directory..."; \
			cd $(ALPINE_DIR) && \
			. ../../$(APK_CACHE_DIR)/versions.env 2>/dev/null || true && \
			for apk in ../../$(APK_CACHE_DIR)/*.apk; do \
				[ -f "$$apk" ] && tar xzf "$$apk" || true; \
			done; \
			echo "Package extraction complete"; \
		fi; \
	fi

# Create initramfs
$(INITRAMFS_CPIO): $(KERNEL_IMAGE) extract-packages
	@echo "Creating initramfs from Alpine Linux..."
	rm -rf $(INITRAMFS_DIR)
	mkdir -p $(INITRAMFS_DIR)
	
	# Copy Alpine rootfs
	@echo "Copying Alpine rootfs..."
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
	
	# Copy kiosk image
	@echo "Copying kiosk image..."
	cp kiosk-image.png $(INITRAMFS_DIR)/root/kiosk-image.png
	
	# Copy run.sh script
	cp run.sh $(INITRAMFS_DIR)/root/run.sh 2>/dev/null || true
	chmod +x $(INITRAMFS_DIR)/root/run.sh 2>/dev/null || true
	
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
		--cmdline="console=tty0 console=ttyS0 earlyprintk=serial,ttyS0,115200 loglevel=7 debug video=1024x768 vga=791 fbcon=nodefer vt.global_cursor_default=0" \
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
	@echo "Window will show framebuffer graphics, terminal shows kernel logs"
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
	@echo "Note: APK cacheusb_boot.code-workspace preserved in $(APK_CACHE_DIR)/"

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
	@echo "  run             - Run in QEMU (window + console logs)"
	@echo "  clean           - Remove build artifacts (preserves APK cache)"
	@echo "  clean-apk       - Remove APK cache directory"
	@echo "  clean-all       - Remove all build artifacts and cache"
	@echo "  help            - Show this help message"
