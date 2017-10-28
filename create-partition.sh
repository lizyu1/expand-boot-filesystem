#!/bin/bash
# Initial draft: lyu14 22 May 2017
# Part II - This script will run second to create the new boot partition /dev/sda3
# 5/9/17 Add scan disk function
# 13/9/17 Add some entropy to the backup filenames; check that the backup dir/files don't already exist


PATH=/bin:/sbin:/usr/bin
BackupDir=/var/tmp/bootinfo
ROOTDISK=/dev/sda

[ -f /var/tmp/`basename $0` ] &&  echo  "script /var/tmp/$basename $0 already been ran, exit" && exit


# Backup the config file into /var/tmp

backup() {

[ -d $BackupDir ] && rm -r /var/tmp/bootinfo

mkdir $BackupDir
cp /etc/fstab $BackupDir/fstab.orig.$$
cp /boot/grub/grub.conf $BackupDir/grub.conf.orig.$$
blkid > $BackupDir/blkid.orig.$$
fdisk -l /dev/sda > $BackupDir/fdisk.sda.orig.$$
df -h > $BackupDir/df-h.orig.$$

}

# Collect the controller number and collect the disk size (round up float to integer)
scan_disk() {

controller=`udevadm info --query=all --name=$ROOTDISK| head -1 | awk -F / '{ print $8 }'`
currentsize=`fdisk -l $ROOTDISK | head -2|grep ^Disk|awk '{ print $3 }' | awk '{print ($0-int($0)<0.499)?int($0):int($0)+1}'`
#currentsize=`printf "%.0f\n" `fdisk -l /dev/sda|head -2|awk '{ print $3 }'``
echo 1 > /sys/class/scsi_device/$controller/device/rescan
newsize=`fdisk -l $ROOTDISK | head -2|grep ^Disk|awk '{ print $3 }' | awk '{print ($0-int($0)<0.499)?int($0):int($0)+1}'`
echo "Current size is $currentsize"
echo "New size is $newsize"
if [ $currentsize -eq $newsize ]
then
        echo "The new size is incorrect. Please scan the disk."
        exit
fi

}

# Create new partition in at the end of the disk
mod_fdisk() {

#Capture the last, new and total cylinder of the disk
LastCharLastLine=`fdisk -l $ROOTDISK| grep -v "does not" | tail -2| head -1 | grep -oE '[^ ]+$'`
if [ $LastCharLastLine == LVM ]
then
        LastCy=`fdisk -l $ROOTDISK |grep -v "does not" | tail -1 | awk '{ print $(NF-3)}'`
else
        LastCy=`fdisk -l $ROOTDISK |grep -v "does not" | tail -1 | awk '{ print $(NF-4)}'`
fi
# make sure it is an integer
if [ ${LastCy//[^[:digit:]]} ]
then
        NewStartCy=`expr $LastCy + 1`
        TotalCy=`fdisk -l $ROOTDISK | sed '3q;d' | awk '{ print $5 }'`
        CurrentPartNum=`fdisk -l $ROOTDISK| egrep -v "does not|Units"|grep "*"|cut -c9`
        LastPartNum=`fdisk -l $ROOTDISK| egrep -v "does not"| tail -1|cut -c9`
        if [ $LastPartNum != 4 ]
        then
                NewPartNum=`expr $LastPartNum + 1`
        fi
        echo "New start cylinder is $NewStartCy"
        echo "Total cylinder is $TotalCy"
        echo "New partition number is $NewPartNum"

        /sbin/fdisk $ROOTDISK << EOF
        p
        n
        p
        $NewPartNum
        $NewStartCy
        $TotalCy
        a
        $NewPartNum
        a
        $CurrentPartNum
        p
        w
        quit
EOF
else
        echo "Last cylinder is not an integer, please investigate"
        exit
fi

}

# Reboot
reboot() {

touch /var/tmp/`basename $0`
echo "Is the new partition correct? y/n"
read answer
if [ $answer == y ]
then
        echo "Server is restarting now..."
        shutdown -r now
else
        echo "Please fix the new partition manually"
        exit
fi

}


backup
scan_disk
mod_fdisk
reboot
