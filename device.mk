#
# Copyright (C) 2021-2025 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

## Bluetooth
# The MT7668 Bluetooth core is a kernel HCI device (btmtksdio), driven by the
# standard AIDL HAL over an HCI user channel, as on mainline targets.
# Read by the g12-common vendor makefile to skip the DroidLogic HIDL HAL.
TARGET_USE_AIDL_BLUETOOTH_HAL := true

PRODUCT_PACKAGES += \
    G12GenericBluetoothOverlay \
    android.hardware.bluetooth-service.default

## Factory
PRODUCT_HOST_PACKAGES += \
    aml_image_packer

## Graphics (Mali)
PRODUCT_PACKAGES += \
    libGLES_mali \
    vendor_lib_hw_vulkan_amlogic_so

## Init-Files
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/init-files/init.amlogic.wifi_buildin.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.amlogic.wifi_buildin.rc

## Wi-Fi (MT7668)
# wlan_mt76x8_sdio is a cfg80211 driver: wpa_supplicant, hostapd and wificond
# talk nl80211 to it directly, so there is no vendor Wi-Fi HAL.
TARGET_HAVE_WIFIHAL := false

# Firmware comes with the driver in kernel/.../vendor/mediatek/mt7668. The
# driver reads its settings from wifi.cfg; use the tuning of the stock
# firmware of this box (BT coexistence, efuse calibration) instead of the
# generic one.
MT7668_FIRMWARE_PATH := kernel/platform/kernel-5.15/vendor/mediatek/mt7668/firmware

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/wifi/wifi.cfg:$(TARGET_COPY_OUT_VENDOR)/lib/firmware/wifi.cfg \
    $(filter-out %/lib/firmware/wifi.cfg,$(call find-copy-subdir-files,*,$(MT7668_FIRMWARE_PATH),$(TARGET_COPY_OUT_VENDOR)/lib/firmware))

## Keylayout (IR)
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/keylayout/Vendor_0001_Product_0001.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/Vendor_0001_Product_0001.kl

## Remote (IR mouse mode)
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/init-files/init.remote.a95x.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.remote.a95x.rc \
    $(foreach f,remote-0xdf00.tab remote-0x4040.tab remote-0x7f80.tab, \
        $(LOCAL_PATH)/remote/$(f):$(TARGET_COPY_OUT_VENDOR)/etc/$(f))


## OpenVFD
# Lineage keeps Soong out of kernel/platform; OpenVFDService lives next to the
# driver there, as on other OpenVFD boxes.
PRODUCT_SOURCE_ROOT_DIRS += kernel/platform/kernel-5.15/vendor/amlogic/openvfd

PRODUCT_PACKAGES += \
    init.openvfd.rc \
    OpenVFDService

## Preinstalled apps
# Removable apps from packages/apps/PreinstallApps, installed on first boot.
# Build with WITH_PREINSTALL_APPS=true to include them.
ifeq ($(WITH_PREINSTALL_APPS),true)
PRODUCT_PACKAGES += \
    preinstall_apps
endif

## TEE
TARGET_HAS_TEE := false

## Soong Namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH)

## Inherit from the common tree product makefile
$(call inherit-product, device/amlogic/g12-common/g12.mk)
