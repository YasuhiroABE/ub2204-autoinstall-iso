
.PHONY: download init setup geniso clean clean-up-all

ISO_URLBASE = https://releases.ubuntu.com/22.04/
ISO_FILENAME = ubuntu-22.04-live-server-amd64.iso
ISO_MOUNTPOINT = /mnt/iso
ISO_ROOT = iso_root

## copy files
GRUBCFG_SRC = config/boot/grub/grub.cfg
GRUBCFG_DEST = iso_root/boot/grub/grub.cfg
ISOLINUXTXT_SRCDIR = config/isolinux
ISOLINUXTXT_DESTDIR = iso_root/isolinux
USERDATA_SRC = config/user-data
USERDATA_DEST = iso_root/user-data
METADATA_SRC = config/meta-data
METADATA_DEST = iso_root/meta-data
EXTRAS_SRCDIR = config/extras/
EXTRAS_DESTDIR = iso_root/

GENISO_LABEL = MYUBISOIMG
GENISO_FILENAME = ubuntu-custom-autoinstaller.$(shell date +%Y%m%d.%H%M%S).iso
GENISO_HYBRIDMBR = /usr/lib/ISOLINUX/isohdpfx.bin
GENISO_ISOLINUX = /usr/lib/ISOLINUX/isolinux.bin
GENISO_SYSMODULES = /usr/lib/syslinux/modules/bios/
GENISO_BOOTCATALOG = /boot.catalog
GENISO_START_SECTOR = $(shell fdisk -l $(ISO_FILENAME) |grep iso2 | cut -d' ' -f2)
GENISO_END_SECTOR = $(shell fdisk -l $(ISO_FILENAME) |grep iso2 | cut -d' ' -f3)

download:
	wget -N $(ISO_URLBASE)/$(ISO_FILENAME)

init:
	sudo apt install isolinux syslinux-common xorriso
	( test -d $(ISO_ROOT) && mv -f $(ISO_ROOT) $(ISO_ROOT).$(shell date +%Y%m%d.%H%M%S) ) || true
	mkdir -p $(ISO_ROOT)
	mkdir -p $(ISOLINUXTXT_DESTDIR)
	mkdir -p $(ISO_MOUNTPOINT)
	cp $(GENISO_ISOLINUX) $(ISOLINUXTXT_DESTDIR)/
	rsync -av $(GENISO_SYSMODULES)/. $(ISOLINUXTXT_DESTDIR)/.
	(mountpoint $(ISO_MOUNTPOINT) && sudo umount -q $(ISO_MOUNTPOINT)) || true
	sudo mount -o ro,loop $(ISO_FILENAME) $(ISO_MOUNTPOINT)
	rsync -av $(ISO_MOUNTPOINT)/. $(ISO_ROOT)/.
	sudo umount $(ISO_MOUNTPOINT)

setup:
	chmod 755 $(ISO_ROOT)
	mkdir -p $(ISOLINUXTXT_DESTDIR)
	chmod 644 $(GRUBCFG_DEST)
	cp -f $(GRUBCFG_SRC) $(GRUBCFG_DEST)
	rsync -av $(ISOLINUXTXT_SRCDIR)/. $(ISOLINUXTXT_DESTDIR)/.
	chmod 755 $(ISO_ROOT)
	cp -f $(USERDATA_SRC) $(USERDATA_DEST)
	cp -f $(METADATA_SRC) $(METADATA_DEST)
	rsync -av $(EXTRAS_SRCDIR)/. $(EXTRAS_DESTDIR)/.

geniso:
	sudo xorriso -as mkisofs -volid $(GENISO_LABEL) \
	-output $(GENISO_FILENAME) \
	-eltorito-boot $(shell basename $(ISOLINUXTXT_DESTDIR))/$(shell basename $(GENISO_ISOLINUX)) \
	-eltorito-catalog $(GENISO_BOOTCATALOG) -no-emul-boot \
	-boot-load-size 4 -boot-info-table -eltorito-alt-boot \
	-no-emul-boot -isohybrid-gpt-basdat \
	-append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b --interval:local_fs:$(GENISO_START_SECTOR)d-$(GENISO_END_SECTOR)d::'$(ISO_FILENAME)' \
	-e '--interval:appended_partition_2_start_1782357s_size_8496d:all::' \
	-isohybrid-mbr $(GENISO_HYBRIDMBR) "${ISO_ROOT}"

clean:
	find . -type f -a -user "$(shell id -un)" -a -name '*~' -exec rm {} \; -print

clean-up-all: clean
	sudo rm -rf iso_root
