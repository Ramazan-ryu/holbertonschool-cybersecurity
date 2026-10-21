#!/bin/bash

# Usage:
# ./12-luks_manager.sh create <size_MB>
# ./12-luks_manager.sh open
# ./12-luks_manager.sh close

VOLUME="encrypted_volume.img"
MAPPER_NAME="secure_vol"
MOUNT_POINT="/mnt/secure_vol"

case $1 in
    create)
        SIZE=$2
        if [ -z "$SIZE" ]; then
            echo "Usage: $0 create <size_MB>"
            exit 1
        fi

        dd if=/dev/zero of=$VOLUME bs=1M count=$SIZE
        sudo cryptsetup luksFormat $VOLUME
        sudo cryptsetup luksOpen $VOLUME $MAPPER_NAME
        sudo mkfs.ext4 /dev/mapper/$MAPPER_NAME
        mkdir -p $MOUNT_POINT
        sudo mount /dev/mapper/$MAPPER_NAME $MOUNT_POINT
        echo "Volume created and mounted at $MOUNT_POINT"
        ;;

    open)
        sudo cryptsetup luksOpen $VOLUME $MAPPER_NAME
        mkdir -p $MOUNT_POINT
        sudo mount /dev/mapper/$MAPPER_NAME $MOUNT_POINT
        echo "Volume opened and mounted"
        ;;

    close)
        sudo umount $MOUNT_POINT
        sudo cryptsetup luksClose $MAPPER_NAME
        echo "Volume unmounted and closed"
        ;;

    *)
        echo "Usage: $0 {create|open|close} [size_MB]"
        exit 1
        ;;
esac
