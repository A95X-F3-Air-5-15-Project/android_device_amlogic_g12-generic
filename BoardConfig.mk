#
# Copyright (C) 2021-2025 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/amlogic/g12-generic

## Bluetooth
BOARD_HAVE_BLUETOOTH := true

## Bootloader
TARGET_BOOTLOADER_BOARD_NAME := g12_generic

## DTB
# One DTB per box, all in boot.img; mainline U-Boot picks the one of the box
# (chainload_board), the first one by default.
TARGET_DTB_NAME := \
    sm1_s905x3_generic_a95xf3air \
    sm1_s905x3_generic_h96maxx3
TARGET_DTBO_NAME := android_overlay_dt
BOARD_KERNEL_SEPARATED_DTBO := true

## Kernel
TARGET_KERNEL_PLATFORM_TARGET := g12_generic
BOARD_VENDOR_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/vendor_dlkm.modules.load))
BOOT_KERNEL_MODULES := $(strip $(shell cat $(DEVICE_PATH)/vendor_boot.modules.load))
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD := $(BOOT_KERNEL_MODULES)
RECOVERY_KERNEL_MODULES := $(BOOT_KERNEL_MODULES)
BOARD_RECOVERY_KERNEL_MODULES_LOAD := $(BOOT_KERNEL_MODULES)

## Partitions
# Dynamic partitions are retrofitted onto the stock Android 9 layout.
# The super metadata lives on system.
BOARD_SUPER_PARTITION_BLOCK_DEVICES := vendor odm system product
BOARD_SUPER_PARTITION_METADATA_DEVICE := system
BOARD_SUPER_PARTITION_VENDOR_DEVICE_SIZE := 268435456
BOARD_SUPER_PARTITION_ODM_DEVICE_SIZE := 134217728
BOARD_SUPER_PARTITION_SYSTEM_DEVICE_SIZE := 1610612736
BOARD_SUPER_PARTITION_PRODUCT_DEVICE_SIZE := 134217728
BOARD_SUPER_PARTITION_SIZE := $(shell echo $$(( \
    $(BOARD_SUPER_PARTITION_VENDOR_DEVICE_SIZE) + \
    $(BOARD_SUPER_PARTITION_ODM_DEVICE_SIZE) + \
    $(BOARD_SUPER_PARTITION_SYSTEM_DEVICE_SIZE) + \
    $(BOARD_SUPER_PARTITION_PRODUCT_DEVICE_SIZE))))

## Properties
TARGET_PRODUCT_PROP += $(DEVICE_PATH)/product.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop

## SELinux
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

## Include the common tree BoardConfig makefile
include device/amlogic/g12-common/BoardConfigCommon.mk

# Replace the legacy DroidLogic HIDL Bluetooth HAL with the standard AIDL HAL.
DEVICE_MANIFEST_FILE := $(filter-out device/amlogic/g12-common/manifest_bt.xml,$(DEVICE_MANIFEST_FILE))

## Kernel
# g12-common points TARGET_KERNEL_SOURCE at its 4.9 kernel, so set the
# 5.15 platform build only after including it.
TARGET_KERNEL_VERSION := 5.15
TARGET_KERNEL_SOURCE := vendor/amlogic/g12-generic-build
