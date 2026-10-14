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

## Graphics (Mali)
PRODUCT_PACKAGES += \
    libGLES_mali \
    vendor_lib_hw_vulkan_amlogic_so

## Init-Files
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/init-files/init.amlogic.wifi_buildin.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.amlogic.wifi_buildin.rc

## Wi-Fi
# Every driver (MT7668, brcmfmac, rtw88) is a cfg80211/mac80211 one:
# wpa_supplicant, hostapd and wificond talk nl80211 to it directly, so there
# is no vendor Wi-Fi HAL.
TARGET_HAVE_WIFIHAL := false

# Firmware comes with the drivers in kernel/.../vendor/mainline-stack, into
# /vendor/lib/firmware (firmware_class.path). The MT7668 driver reads its
# settings from wifi.cfg; use the tuning of the stock A95X F3 Air firmware
# (BT coexistence, efuse calibration) instead of the generic one.
MAINLINE_STACK_PATH := kernel/platform/kernel-5.15/vendor/mainline-stack

MAINLINE_STACK_FIRMWARE := $(foreach d,mt7668 rtw88 brcm, \
    $(call find-copy-subdir-files,*,$(MAINLINE_STACK_PATH)/$(d)/firmware,$(TARGET_COPY_OUT_VENDOR)/lib/firmware))

# Leave out the READMEs and licences, and the generic MT7668 wifi.cfg.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/wifi/wifi.cfg:$(TARGET_COPY_OUT_VENDOR)/lib/firmware/wifi.cfg \
    $(foreach f,$(filter-out %/wifi.cfg %.md,$(MAINLINE_STACK_FIRMWARE)), \
        $(if $(findstring /LICENCE,$(f)),,$(f)))

## Keylayout (IR)
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/keylayout/Vendor_0001_Product_0001.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/Vendor_0001_Product_0001.kl

## Remote (IR)
# The remote tables of every box: each is keyed by the custom code of its
# remote, so they all coexist in the IR driver.
#
# A95X F3 Air: loaded by init.remote.a95x.rc, mainly for the mouse mode,
# which the DTB maps cannot set.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/init-files/init.remote.a95x.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.remote.a95x.rc \
    $(foreach f,remote-0xdf00.tab remote-0x4040.tab remote-0x7f80.tab, \
        $(LOCAL_PATH)/remote/a95xf3air/$(f):$(TARGET_COPY_OUT_VENDOR)/etc/$(f))

# H96 Max X3: the stock remote.cfg and remote.tab1-3, which g12-common loads
# with remotecfg1-3 from persist.vendor.amlogic.remotecfg.path, padded for
# the 5.15 IR driver (from device/haochuangyi/h96maxx3).
PRODUCT_COPY_FILES += \
    $(foreach f,remote.cfg remote.tab1 remote.tab2 remote.tab3, \
        $(LOCAL_PATH)/remote/h96maxx3/$(f):$(TARGET_COPY_OUT_VENDOR)/etc/remote/$(f))


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
