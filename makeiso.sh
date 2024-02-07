#!/bin/bash

set -e

ISO="debian-live_$(date +%Y%m%d).iso"

f_log() {
    echo $(date "+%d.%.m%.Y@%H:%M:%S") $@
}

f_usage() {
    cat << EOF
Usage: makeiso.sh [clear|build]
EOF
}

f_prepare() {
    rm -rfv output
    mkdir -p output/{rootfs,image/{live,boot/grub}}
    sort -o packages.list packages.list
    touch .f_prepare
}

f_packages_list() {
    local list=$(tr '\n' ',' < packages.list)
    echo ${list%,}
}

f_debootstrap() {
    debootstrap \
	    --arch=amd64 \
        --include=$(f_packages_list) \
	    --components=main,contrib,non-free,non-free-firmware \
	    testing \
	    output/rootfs \
	    http://deb.debian.org/debian/
    touch .f_debootstrap
}

f_autologin() {
    mkdir -p output/rootfs/etc/systemd/system/getty@tty1.service.d/
    cat <<EOF > output/rootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin root - $TERM
EOF
    echo "debian" > output/rootfs/etc/hostname
    touch .f_autologin
}

f_locales() {
    echo "en_US.UTF-8 UTF-8" >> output/rootfs/etc/locale.gen
    echo "ru_RU.UTF-8 UTF-8" >> output/rootfs/etc/locale.gen
    chroot output/rootfs/ locale-gen
    echo "LANG=en_US.UTF-8" >> output/rootfs/etc/default/locale
    echo "LANGUAGE=en_US.UTF-8" >> output/rootfs/etc/default/locale
    touch .f_locales
}

f_mksquashfs() {
    cp -v output/rootfs/boot/vmlinuz-* output/image/live/vmlinuz
    cp -v output/rootfs/boot/initrd.img-* output/image/live/initrd
    mksquashfs output/rootfs output/image/live/filesystem.squashfs -noappend -comp xz -e boot
    touch .f_mksquashfs
}

f_grub_config(){
    cat <<EOF > output/image/boot/grub/grub.cfg

search --set=root --label debian-live

insmod all_video

set default="0"
set timeout=30

menuentry "Debian Live" {
    linux (\$root)/live/vmlinuz boot=live quiet
    initrd (\$root)/live/initrd
}
EOF
    touch .f_grub_config
}

f_makeiso() {
    /usr/bin/grub-mkrescue -volid "debian-live" -o ${ISO} output/image
    sha256sum ${ISO} > ${ISO}.sha256
    touch .f_makeiso
}

f_main() {
    if [ $EUID -ne 0 ]; then
        echo "Need root!"
        exit 1
    fi
    case $1 in
        clear)
            rm -fv .f_*
            rm -rfv output
            rm -fv *.iso *.sha256
            ;;
        build)
            test -f .f_prepare || f_prepare
            test -f .f_debootstrap || f_debootstrap
            test -f .f_autologin || f_autologin
            test -f .f_locales || f_locales
            test -f .f_mksquashfs || f_mksquashfs
            test -f .f_grub_config || f_grub_config
            test -f .f_makeiso || f_makeiso
            ;;
        *)
            f_usage
            ;;
    esac
}

f_main $@

