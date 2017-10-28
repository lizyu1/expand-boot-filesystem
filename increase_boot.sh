#!/bin/bash
# liz 22 May 2017
# Part III - last script to be run, after new partition has been created

PATH=/sbin:/usr/bin:/bin:/usr/local/bin
ROOTDISK=/dev/sda

get_partition_number() { 

fdisk -l $ROOTDISK
echo 
echo "Please enter the new disk partition number. E.g. sda3"
read num
fdisk -l /dev/$num > /dev/null
if [ $? == 1 ]
then
	echo "Not a valid disk partition number"
	exit
fi
partname=$num

}


make_fs() {

var=`file -s /dev/$partname | awk '{ print $2 }'`
if [ $var = data ]
then
	mkfs.ext4 /dev/$partname
else
	echo "$partnam doesn't exist after reboot, need investigation"
	exit
fi

}


mount_n_copy_boot_data() {

[ -d /mnt/boot ] || mkdir /mnt/boot
mount /dev/$partname /mnt/boot
cp -dpRx /boot/* /mnt/boot/

}

update_fstab() {

NewUUID=`facter -p partitions./dev/$partnum.uuid`
CurrUUID=`egrep '^UUID.*/boot' /etc/fstab | awk '{ print $1 }' cut -d "=" -f 2`
echo "New UUID is $NewUUID"

if [ ! -z $NewUUID ]
then
	sed -i -e "s/$CurrUUID/$NewUUID/g" /etc/fstab
	awk '!/^#/ && /boot/ { $3 = "ext4" }1 ' /etc/fstab > /tmp/$$
	mv /tmp/$$ /etc/fstab
else
	echo "No filesystem type on /dev/$partname, need investigation, exit"
	exit
fi

}


update_mbr() {

var=`echo $partnum |grep -o '.$'`
var1=`expr $var - 1`

grub << EOF
device (hd0) /dev/sda
root (hd0,$var1)
setup (hd0)
quit
EOF

echo "Modify grub.conf"
CurrentBoot=`grep splashimage /mnt/boot/grub/grub.conf | cut -c 18`
echo $CurrentBoot
sed -i -e "s/hd0,$CurrentBoot/hd0,$var1/g" /mnt/boot/grub/grub.conf
}

reboot() {

cat /mnt/boot/grub/grub.conf
echo
echo "Is the grub.conf correct? y/n"
read answer
if [ $answer == y ]
then
	echo "Server is restarting now..."
	shutdown -r now
else
	echo "Please manually fix the grub.conf in the new partition"
	exit
fi

[ -f /var/tmp/create-partition.sh ] && rm -f /var/tmp/create-partition.sh

}

get_partition_number
make_fs
mount_n_copy_boot_data
update_fstab
update_mbr
reboot

