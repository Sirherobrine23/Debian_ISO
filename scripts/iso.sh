#!/bin/bash
cd /home/iso
DIR_CH=`pwd`
echo $USER
echo $EUID
echo "::group::Ngrok"
/etc/init.d/nginx restart
ngrok authtoken $INPUT_NGROK_TOKEN
screen -dm ngrok http 80
sleep 20s
echo "Ngrok Url: $(curl -s localhost:4040/api/tunnels | jq -r .tunnels[1].public_url), $(curl -s localhost:4040/api/tunnels | jq -r .tunnels[0].public_url)"
# echo "Access the tunnels on https://dashboard.ngrok.com/status/tunnels"
echo "::endgroup::"
echo "**********************************"
echo "* Script file: ${INPUT_SCRIPT}"
echo "* Dist name: ${INPUT_DIST}"
echo "* Dist base: ${INPUT_DIST_BASE}"
echo "**********************************"

echo "Creating chroot environment, wait"
mkdir -p image/{casper,isolinux,install,log}
if [ ${INPUT_DIST_BASE} == "debian" ];then
    echo "Debian may have Panic kernel, use Ubuntu"
    if debootstrap buster chroot/ ${INPUT_REPO_URL} &>> buster.txt;then
        echo "Debian Buster (10)"
    elif debootstrap stretch chroot/ ${INPUT_REPO_URL} &>> stretch.txt;then
        echo "Debian stretch (9)"
    elif debootstrap jessie chroot/ ${INPUT_REPO_URL} &>> jessie.txt;then
        echo "Debian Jessie (8)"
    else
        echo "Error creating chroot with debootstrap"
        cat *.txt
        exit 200
    fi
    echo 'Image created by Sirherobrine23 with Debian distro' > chroot/iso_by
elif [ ${INPUT_DIST_BASE} == "ubuntu" ];then
    if debootstrap groovy chroot/ ${INPUT_REPO_URL} &>> groovy.txt;then
        echo "Ubuntu groovy (20.10)"
    elif debootstrap focal chroot/ ${INPUT_REPO_URL} &>> focal.txt;then
        echo "Ubuntu Focal (20.04)"
    elif debootstrap bionic chroot/ ${INPUT_REPO_URL} &>> bionic.txt;then
        echo "Ubuntu Bionic (18.04)"
    else
        echo "Error creating chroot with debootstrap"
        cat *.txt
        exit 200
    fi
    echo 'Image created by Sirherobrine23 with ubuntu distro' > chroot/iso_by
else
    echo "The distro (${INPUT_DIST_BASE}) does not support this script"
    exit 1
fi
mount --bind /dev chroot/dev &>> /dev/null
mount --bind /run chroot/run &>> /dev/null
mount --bind /github/workspace/ chroot/mnt &>> /dev/null


echo "export INPUT_DIST=\"$INPUT_DIST\"" > chroot/tmp/envs.sh
echo "export INPUT_SCRIPT=\"$INPUT_SCRIPT\"" >> chroot/tmp/envs.sh
echo "export GITHUB_ENV=\"$GITHUB_ENV\"" >> chroot/tmp/envs.sh
echo "export GITHUB_ACTION_PATH=\"/home/iso/\"" >> chroot/tmp/envs.sh
echo "export NGROK=\"$INPUT_NGROK_TOKEN\"" >> chroot/tmp/envs.sh
echo "export NGROK_TIME=\"$INPUT_NGROK_WEB_TIME\"" >> chroot/tmp/envs.sh
echo "export WORK_PATH=\"/home/iso/\"" >> chroot/tmp/envs.sh
echo "export R_U=\"$INPUT_REPO_URL\"" >> chroot/tmp/envs.sh


echo "/home/iso/chroot_script/pre.sh chroot/tmp/pre.sh"
echo "/github/workspace/${INPUT_SCRIPT} chroot/tmp/script.sh"
echo "/home/iso/chroot_script/post.sh chroot/tmp/post.sh"

cp -fv /home/iso/pre.sh chroot/tmp/pre.sh
cp -fv /github/workspace/${INPUT_SCRIPT} chroot/tmp/script.sh
cp -fv /home/iso/post.sh chroot/tmp/post.sh

chroot chroot/ bash /tmp/pre.sh

chroot chroot/ bash /tmp/script.sh

echo "::group::Post script"
    chroot chroot/ bash /tmp/post.sh
echo "::endgroup::"

rm -rvf chroot/tmp/script.sh chroot/tmp/pre.sh chroot/tmp/post.sh chroot/tmp/*
echo "Unmounting some partitions"
umount chroot/* &>> /dev/null
echo "Creating the directories to create the ISO"
echo "Copying vmlinuz and initrd"
cd chroot/
if [ -e vmlinuz ];then
    cp -fv vmlinuz $DIR_CH/image/casper/vmlinuz
elif [ -e boot/vmlinuz-* ];then
    cp -fv boot/vmlinuz-* $DIR_CH/image/casper/vmlinuz
else
    echo "$(pwd): $(ls -la)"
    echo "Without the vmlinuz file"
    exit 23
fi
if [ -e initrd.img ];then
    cp -fv initrd.img $DIR_CH/image/casper/initrd
elif [ -e boot/initrd.img-* ];then
    cp -fv boot/initrd.img-* $DIR_CH/image/casper/initrd
else
    echo "$(pwd): $(ls -la)"
    echo "Without the initrd.img file"
    exit 24
fi
cd ../

touch image/ubuntu
echo "Creating the GRUB file"
echo "
#search --set=root --file /ubuntu

insmod all_video

set default=\"0\"
set timeout=10

menuentry \"${INPUT_DIST}\" {
    
    linux /casper/vmlinuz root=/system/ rw
    initrd /casper/initrd
}

" > image/isolinux/grub.cfg
chroot chroot dpkg-query -W --showformat='${Package} ${Version}\n' | tee image/casper/filesystem.manifest >/dev/null 2>&1
cp -v image/casper/filesystem.manifest image/casper/filesystem.manifest-desktop
sed -i '/ubiquity/d' image/casper/filesystem.manifest-desktop
sed -i '/casper/d' image/casper/filesystem.manifest-desktop
sed -i '/discover/d' image/casper/filesystem.manifest-desktop
sed -i '/laptop-detect/d' image/casper/filesystem.manifest-desktop
sed -i '/os-prober/d' image/casper/filesystem.manifest-desktop
echo "Creating the file with the image size"
printf $(du -sx --block-size=1 chroot/ | cut -f1) > image/casper/filesystem.size
echo "Chroot size: $(cat image/casper/filesystem.size)"
echo "----------------------------"
echo "Creating the filesystem.squashfs"
# mksquashfs ./chroot/ image/casper/filesystem.squashfs
mv -vf ./chroot/. image/system/
echo "----------------------------"
echo "..."
echo "#define DISKNAME  ${INPUT_DIST}
#define TYPE  binary
#define TYPEbinary  1
#define ARCH  amd64
#define ARCHamd64  1
#define DISKNUM  1
#define DISKNUM1  1
#define TOTALNUM  0
#define TOTALNUM0  1" > image/README.diskdefines

echo "Copying the logs to image/log"
cp -fv *.txt image/log
cd $DIR_CH/image/ || {
    echo "Erro"
    exit 25
}
echo "Creating GRUB entries"
grub-mkstandalone --format=x86_64-efi --output=isolinux/bootx64.efi --locales="" --fonts="" "boot/grub/grub.cfg=isolinux/grub.cfg" || {
    echo "Error creating entry for efi"
    exit $?
}

(
   cd isolinux && \
   dd if=/dev/zero of=efiboot.img bs=1M count=10 && \
   mkfs.vfat efiboot.img && \
   LC_CTYPE=C mmd -i efiboot.img efi efi/boot && \
   LC_CTYPE=C mcopy -i efiboot.img ./bootx64.efi ::efi/boot/
)

grub-mkstandalone --format=i386-pc --output=isolinux/core.img --install-modules="linux16 linux normal iso9660 biosdisk memdisk search tar ls" --modules="linux16 linux normal iso9660 biosdisk search" --locales="" --fonts="" "boot/grub/grub.cfg=isolinux/grub.cfg" || {
    echo "erro no bios"
    exit $?
}

cat /usr/lib/grub/i386-pc/cdboot.img isolinux/core.img > isolinux/bios.img
echo "Creating md5sum"
/bin/bash -c "(find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > md5sum.txt)"
mkdir ../ISO/
echo "Creating ISO"
xorriso -as mkisofs -verbose -iso-level 3 -full-iso9660-filenames -volid "${INPUT_DIST}" -eltorito-boot boot/grub/bios.img -no-emul-boot -boot-load-size 4 \
-boot-info-table --eltorito-catalog boot/grub/boot.cat --grub2-boot-info --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img -eltorito-alt-boot -e EFI/efiboot.img \
-no-emul-boot -append_partition 2 0xef isolinux/efiboot.img -output "../ISO/${INPUT_DIST}.iso" \
-graft-points "." /boot/grub/bios.img=isolinux/bios.img  /EFI/efiboot.img=isolinux/efiboot.img || {
    XO_ERRO=$? 
    echo "xorriso erro: $XO_ERRO"
    exit $XO_ERRO
}
cd ../ISO
cp -fv "${INPUT_DIST}.iso" /github/workspace/
echo "Defining the file path ${INPUT_DIST}.iso"
echo "ISO_PATH_FILE=${INPUT_DIST}.iso" >> ${GITHUB_ENV}
echo "ISO_PATH_SUCESS=0" >> ${GITHUB_ENV}
echo "Sucess"
exit 0
