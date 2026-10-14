#
# Copyright (C) 2021-2023 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

ifneq ($(filter g12_generic,$(TARGET_DEVICE)),)

LOCAL_PATH := device/amlogic/g12-generic
FACTORY_PATH := device/amlogic/g12-generic/factory

# Only misc belongs in target-files/OTA. The bootloader payloads below are
# used to start the Amlogic burning environment and must never be OTA-flashed.
# misc.img and rsv.img come from factory/mkbootfiles.py: the mainline U-Boot
# in rsv boots LineageOS, misc makes the stock U-Boot chainload it.
RADIO_FILES := $(FACTORY_PATH)/bootfiles/misc.img
$(foreach f, $(notdir $(RADIO_FILES)), \
    $(call add-radio-file,factory/bootfiles/$(f)))

# The *_ENC loaders and the meson1 DTBs are the stock ones: the box has secure
# boot, so the burning tool needs the signed loaders, and the stock U-Boot only
# takes the signed DTB (with the stock partition table) for _aml_dtb. Linux
# gets its DTB from boot.img/recovery.img through the mainline U-Boot.
AML_FACTORY_BOOT_FILES := \
    $(FACTORY_PATH)/bootfiles/DDR.USB \
    $(FACTORY_PATH)/bootfiles/DDR_ENC.USB \
    $(FACTORY_PATH)/bootfiles/UBOOT.USB \
    $(FACTORY_PATH)/bootfiles/UBOOT_ENC.USB \
    $(FACTORY_PATH)/bootfiles/aml_sdc_burn.UBOOT \
    $(FACTORY_PATH)/bootfiles/aml_sdc_burn.UBOOT.ENC \
    $(FACTORY_PATH)/bootfiles/meson1.dtb \
    $(FACTORY_PATH)/bootfiles/meson1_ENC.dtb \
    $(FACTORY_PATH)/bootfiles/rsv.img

PRODUCT_INSTALL_OUT := $(PRODUCT_OUT)/aml_install
PRODUCT_UPGRADE_OUT := $(PRODUCT_OUT)/aml_upgrade
INSTALL_PACKAGE_CONFIG_FILE := $(PRODUCT_INSTALL_OUT)/image_install.cfg
UPGRADE_PACKAGE_CONFIG_FILE := $(PRODUCT_UPGRADE_OUT)/image_upgrade.cfg
AML_IMAGE_TOOL := $(HOST_OUT_EXECUTABLES)/aml_image_packer$(HOST_EXECUTABLE_SUFFIX)

INSTALLED_AML_INSTALL_PACKAGE_TARGET := $(PRODUCT_OUT)/aml_install_package.img
INSTALLED_AML_UPGRADE_PACKAGE_TARGET := $(PRODUCT_OUT)/aml_upgrade_package.img

define aml-copy-install-file
	$(hide) $(ACP) $(1) $(PRODUCT_INSTALL_OUT)/$(strip $(if $(2), $(2), $(notdir $(1))))
endef

define aml-copy-upgrade-file
	$(hide) $(ACP) $(1) $(PRODUCT_UPGRADE_OUT)/$(strip $(if $(2), $(2), $(notdir $(1))))
endef

UPGRADE_IMAGES := \
    boot.img \
    recovery.img \
    dtbo.img \
    vbmeta.img \
    logo.img \
    misc.img

INSTALL_IMAGES := \
    boot.img \
    recovery.img \
    dtbo.img \
    vbmeta.img \
    logo.img \
    misc.img

# Dynamic partitions are retrofitted, so there is no super.img: build the
# split images (super_<device>.img) for the physical partitions instead.
AML_SUPER_SPLIT_OUT := $(call intermediates-dir-for,PACKAGING,aml_super_split)
AML_SUPER_SPLIT_INFO := $(AML_SUPER_SPLIT_OUT)/misc_info.txt
AML_SUPER_SPLIT_STAMP := $(AML_SUPER_SPLIT_OUT)/images.stamp
AML_SUPER_SPLIT_IMAGES := $(foreach d,$(BOARD_SUPER_PARTITION_BLOCK_DEVICES),$(AML_SUPER_SPLIT_OUT)/images/super_$(d).img)

$(AML_SUPER_SPLIT_STAMP): $(LPMAKE) $(BUILD_SUPER_IMAGE) \
    $(foreach p,$(BOARD_SUPER_PARTITION_PARTITION_LIST),$(INSTALLED_$(call to-upper,$(p))IMAGE_TARGET))
	$(hide) rm -rf $(AML_SUPER_SPLIT_OUT)
	$(hide) mkdir -p $(AML_SUPER_SPLIT_OUT)/images
	$(call dump-super-image-info,$(AML_SUPER_SPLIT_INFO))
	$(foreach p,$(BOARD_SUPER_PARTITION_PARTITION_LIST), \
	    echo "$(p)_image=$(INSTALLED_$(call to-upper,$(p))IMAGE_TARGET)" >> $(AML_SUPER_SPLIT_INFO);)
	PATH=$(dir $(LPMAKE)):$$PATH \
	    $(BUILD_SUPER_IMAGE) -v $(AML_SUPER_SPLIT_INFO) $(AML_SUPER_SPLIT_OUT)/images
	$(hide) touch $@

$(AML_SUPER_SPLIT_IMAGES): $(AML_SUPER_SPLIT_STAMP)

# $(1): output directory
define aml-copy-super-split-files
	$(hide) $(foreach d,$(BOARD_SUPER_PARTITION_BLOCK_DEVICES), \
	    $(ACP) $(AML_SUPER_SPLIT_OUT)/images/super_$(d).img $(1)/$(d).img &&) true
endef

# aml_install_package.img only carries what the box needs to start, as on
# radxa0: empty dynamic partitions metadata instead of the system/vendor/odm/
# product images, with misc booting it into recovery to install the build
# with adb sideload. aml_upgrade_package.img carries the full images.
AML_SUPER_EMPTY_OUT := $(call intermediates-dir-for,PACKAGING,aml_super_empty)
AML_SUPER_EMPTY_IMAGE := $(AML_SUPER_EMPTY_OUT)/super_$(BOARD_SUPER_PARTITION_METADATA_DEVICE).img

# Same layout as the split images above, with every logical partition empty.
# Only the metadata device needs to be written for that.
$(AML_SUPER_EMPTY_IMAGE): $(LPMAKE)
	$(hide) rm -rf $(AML_SUPER_EMPTY_OUT)
	$(hide) mkdir -p $(AML_SUPER_EMPTY_OUT)
	$(LPMAKE) --metadata-size 65536 --metadata-slots 2 \
	    --super-name $(BOARD_SUPER_PARTITION_METADATA_DEVICE) \
	    $(foreach d,$(BOARD_SUPER_PARTITION_BLOCK_DEVICES), \
	        --device $(d):$(BOARD_SUPER_PARTITION_$(call to-upper,$(d))_DEVICE_SIZE)) \
	    $(foreach g,$(BOARD_SUPER_PARTITION_GROUPS), \
	        --group $(g):$(BOARD_$(call to-upper,$(g))_SIZE) \
	        $(foreach p,$(BOARD_$(call to-upper,$(g))_PARTITION_LIST),--partition $(p):none:0:$(g))) \
	    --sparse --force-full-image --output $(AML_SUPER_EMPTY_OUT)

$(INSTALLED_AML_INSTALL_PACKAGE_TARGET): $(addprefix $(PRODUCT_OUT)/,$(INSTALL_IMAGES)) $(AML_SUPER_EMPTY_IMAGE) $(AML_FACTORY_BOOT_FILES) $(ACP) $(AML_IMAGE_TOOL)
	$(hide) mkdir -p $(PRODUCT_INSTALL_OUT)
	$(hide) $(foreach f,$(AML_FACTORY_BOOT_FILES),$(ACP) $(f) $(PRODUCT_INSTALL_OUT)/ &&) true
	$(hide) $(call aml-copy-install-file, $(PRODUCT_OUT)/logo.img)
	$(hide) $(call aml-copy-install-file, $(FACTORY_PATH)/aml_sdc_burn.ini)
	$(hide) $(call aml-copy-install-file, $(FACTORY_PATH)/image_install.cfg, image.cfg)
	$(hide) $(call aml-copy-install-file, $(FACTORY_PATH)/platform.conf)
	$(hide) $(call aml-copy-install-file, $(PRODUCT_OUT)/boot.img)
	$(hide) $(call aml-copy-install-file, $(PRODUCT_OUT)/recovery.img)
	$(hide) $(call aml-copy-install-file, $(PRODUCT_OUT)/dtbo.img)
	$(hide) $(call aml-copy-install-file, $(AML_SUPER_EMPTY_IMAGE), $(BOARD_SUPER_PARTITION_METADATA_DEVICE).img)
	$(hide) $(call aml-copy-install-file, $(PRODUCT_OUT)/vbmeta.img)
	$(hide) $(call aml-copy-install-file, $(PRODUCT_OUT)/misc.img)
	$(hide) $(AML_IMAGE_TOOL) -r  $(PRODUCT_INSTALL_OUT)/image.cfg $(PRODUCT_INSTALL_OUT)/ $@
	$(hide) rm -rf $(PRODUCT_INSTALL_OUT)
	$(hide) echo " $@ created"

.PHONY: aml_install
aml_install: $(INSTALLED_AML_INSTALL_PACKAGE_TARGET)

BUILT_TARGET_FILES_ZIPROOT := $(call intermediates-dir-for,PACKAGING,target_files)/$(TARGET_PRODUCT)-target_files
$(BUILT_TARGET_FILES_ZIPROOT).zip: $(BUILT_TARGET_FILES_ZIPROOT)/IMAGES/aml_install_package.img

$(BUILT_TARGET_FILES_ZIPROOT)/IMAGES/aml_install_package.img: $(BUILT_TARGET_FILES_ZIPROOT).zip.list $(PRODUCT_OUT)/aml_install_package.img
	@mkdir -p $(dir $@)
	@cp $(PRODUCT_OUT)/aml_install_package.img $@
	@echo $@ >> $(BUILT_TARGET_FILES_ZIPROOT).zip.list

INSTALLED_RADIOIMAGE_TARGET += $(INSTALLED_AML_INSTALL_PACKAGE_TARGET)

$(INSTALLED_AML_UPGRADE_PACKAGE_TARGET): $(addprefix $(PRODUCT_OUT)/,$(UPGRADE_IMAGES)) $(AML_SUPER_SPLIT_IMAGES) $(AML_FACTORY_BOOT_FILES) $(ACP) $(AML_IMAGE_TOOL)
	$(hide) mkdir -p $(PRODUCT_UPGRADE_OUT)
	$(hide) $(foreach f,$(AML_FACTORY_BOOT_FILES),$(ACP) $(f) $(PRODUCT_UPGRADE_OUT)/ &&) true
	$(hide) $(call aml-copy-upgrade-file, $(PRODUCT_OUT)/logo.img)
	$(hide) $(call aml-copy-upgrade-file, $(FACTORY_PATH)/aml_sdc_burn.ini)
	$(hide) $(call aml-copy-upgrade-file, $(FACTORY_PATH)/image_upgrade.cfg, image.cfg)
	$(hide) $(call aml-copy-upgrade-file, $(FACTORY_PATH)/platform.conf)
	$(hide) $(call aml-copy-upgrade-file, $(PRODUCT_OUT)/boot.img)
	$(hide) $(call aml-copy-upgrade-file, $(PRODUCT_OUT)/recovery.img)
	$(hide) $(call aml-copy-upgrade-file, $(PRODUCT_OUT)/dtbo.img)
	$(call aml-copy-super-split-files,$(PRODUCT_UPGRADE_OUT))
	$(hide) $(call aml-copy-upgrade-file, $(PRODUCT_OUT)/vbmeta.img)
	$(hide) $(call aml-copy-upgrade-file, $(PRODUCT_OUT)/misc.img)
	$(hide) $(AML_IMAGE_TOOL) -r  $(PRODUCT_UPGRADE_OUT)/image.cfg $(PRODUCT_UPGRADE_OUT)/ $@
	$(hide) rm -rf $(PRODUCT_UPGRADE_OUT)
	$(hide) echo " $@ created"

.PHONY: aml_upgrade
aml_upgrade: $(INSTALLED_AML_UPGRADE_PACKAGE_TARGET)

$(BUILT_TARGET_FILES_DIR): $(INSTALLED_RADIOIMAGE_TARGET)

endif
