#!/bin/sh
# Native osm0sis/AnyKernel3 configuration; core owns all boot image handling.
# These variables are consumed by tools/ak3-core.sh.
# shellcheck disable=SC2034

# Parsed as metadata by update-binary, never invoked as a shell function.
# shellcheck disable=SC2289
properties() { '
kernel.string=BakaSU AOSP GKI 2.0
do.devicecheck=0
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
'; }

BLOCK=boot;
IS_SLOT_DEVICE=auto;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;
NO_BLOCK_DISPLAY=1;

# shellcheck source=/dev/null
. tools/ak3-core.sh;
split_boot;
flash_boot;
