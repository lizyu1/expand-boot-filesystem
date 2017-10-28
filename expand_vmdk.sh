#!/bin/bash
# liz 22 May 2017
# Part I - Expand the VMDK file by 1 GB

ddate=`date +%d%h%Y%H%M`

Syd_vCentre () {

cat << EOF

Please select the vCentre in Sydney

1) Syd1
2) Syd2

EOF
read Syd_vCentre

case $Syd_vCentre in

1) VCenter=vcenter1; Syd_ESX_Syd1 ;;
2) VCenter=vcenter2; Syd_ESX_Syd2 ;;
3) VCenter=vcenter3; Syd_ESX_Syd3 ;;
esac

}

Syd_ESX_Syd1 () {

cat << EOF

Please select the ESX for vCenter1

1) syddev01
2) syddev02

EOF
read Syd_ESX_Syd1
case $Syd_ESX_Syd1 in

1) ESXHost=10.10.0.2 ;;
2) ESXHost=10.10.0.3 ;;
*) echo "Invalid input, please try again"; Syd_ESC_Syd1 ;;
esac

}

Syd_ESX_Syd2 () {

cat << EOF

Please select the ESX for vCenter2

1) syduat01
2) syduat02

EOF

read Syd_ESX_Syd2
case $Syd_ESX_Syd2 in

1) ESXHost=10.10.0.4 ;;
2) ESXHost=10.10.0.5 ;;
*) echo "Invalid input, please try again"; Syd_ESC_Syd2 ;;
esac

}


Syd_ESX_Syd3 () {

cat << EOF

Please select the ESX for vCenter3

1) sydsit01
2) sydsit02

EOF

read Syd_ESX_Syd3
case $Syd_ESX_Syd3 in

1) ESXHost=10.10.0.6 ;;
2) ESXHost=10.10.0.7 ;;
*) echo "Invalid input, please try again"; Syd_ESC_Syd3 ;;
esac

}


#Clone backup

vm_backup() {

DataStoreList=`vifs --server $ESXHost --username $ESX_User --password $ESX_Pass -S | egrep -v 'Content|Listing|-----'`
for DStore in $DataStoreList
do
	DS=`echo $VMDK_file| awk -F / '{ print $4 }'`
	if [ $DS = $DStore ]
	then
		DataStore=$DStore
	fi
done

DeltaFile=`vifs --server $ESXHost --username $ESX_User --password $ESX_Pass -D "[$DataStore] $Host"| grep "delta" | sort -r | grep -v '$Host_' | head -n 1`

if [ ! -z $DeltaFile ]
then
	source_vmdk=/vmfs/volumes/$DataStore/$Host/$DeltaFile
else
	source_vmdk=/vmfs/volumes/$DataStore/$Host/$Host.vmdk
fi

echo "Running a VM Backup, please wait..."
destination_vmdk=`dirname $source_vmdk`/"$Host"_clone-$ddate.vmdk
vmkfstools --server $ESXHost --username $ESX_User --password $ESX_Pass -i $source_vmdk $destination_vmdk -d thin

echo "VM Backup completed"

}

vm_check_snapshot() {

echo "Check whether the VM has a snapshot or not"
VAR=`vmware-cmd -H $VCenter --vihost $ESXHost -U $VCenter_User -P $VCenter_Pass $VMX_file hassnapshot | grep -o '.$'`
if [ $VAR -eq 0 ]
then
	echo "continue"
else
	echo "This VM has snapshot, need to remove them before proceed further"
	exit
fi

}


#Power off VM
power_off_vm() {

echo "Power off $Host, please wait.."
vmware-cmd -H $VCentre --vihost $ESXHost -U $VCenter_User -P $VCenter_Pass $VMX_file stop soft
echo "$Host has been shutdown"

}


#Power on VM
power_on() {

echo "Power on $Host, please wait.."
vmware-cmd -H $VCentre --vihost $ESXHost -U $VCenter_User -P $VCenter_Pass $VMX_file start
echo "$Host has been started"

}


#List datastores
List_datastores() {
vifs --server $ESXHost --username $ESX_User --password $ESXPass -S
}

List_all_vmdk() {
vifs --serevr $ESXHost --username $ESX_User --password $ESXPass -D "[StorageName] $Host"
}

expand_vm_disk() {

if [ -n $CurrSize ] && [ ! -z "$CurrSize##*[!0-9]*}" ]
then
	NewSize=`expr $CurrSize + 1`
	echo "Expanding the root disk on $Host to $NewSize GB"
	vmkfstools --server $ESXHost --username $ESX_User --password $ESX_Pass -C "NewSize"G $VMDK_file
	echo "Disk expansion has been completed"
else
	echo "It needs to be a numeric value"
fi
}

echo "Please enter the VM Hostname: "
read vm
Host=$vm

if [ ! -z $vm ] && [ -z "${vm##*syd*}" ]
then
	region=Syd
else
	region=unknown
fi

case $region in
Syd)
	Syd_vCenter
;;
unknown)
	echo "Please enter a valid VM, the hostname should contain a region like 'syd', 'hkg' or 'nyc'"
	exit
;;
esac


echo  Please enter the VCentre Login name: "
read vCenter_User
if [ -z $VCenter_User ]
then
	echo "Cannot be zero input"
	exit
fi

VCenter_User=$VCenter_User

echo "Please enter the vCenter password: "
read VCenter_Pass
if [ -z $VCenter_Pass ]
then
	echo "Cannot be zero input"
	exit
fi

VCenter_Pass=$VCenter_Pass

echo "Please enter the ESX login name: "
read ESX_User
if [ -z $ESX_User ]
then
	echo "Cannot be zero input"
	exit
fi

ESX_User=$ESX_User

echo "Please enter the ESX password: "
read ESX_Pass
if [ -z $ESX_Pass ]
then
	echo "Cannot be zero input"
	exit
fi

ESX_Pass=$ESX_Pass

echo "Please enter the full path of the VMDK file. E.g. /vmfs/volumes/datastore1_987/usydinl29/usydinl29.vmdk"
read VMDK_file
if [ -z $VMDK_file ]
then
	echo "Cannot be zero input"
	exit
fi

VMDK_file=$VMDK_file

echo "Please enter the current size in GB of the root disk. E.g. 50 "
read CurrSize
if [ -z "${CurrSize##*[!0-9]*}" ]
then
	echo "Exit! It needs to be an integer"
	exit
fi
CurrSize=$CurrSize


validate_input () {

echo
echo "VCenter is $VCenter"
echo "ESX host is $ESXHost"
echo "VMDK file is $VMDK_file"
echo "Root disk is $Currsize GB"
echo "Is these correct? Y/n"
read input
if [ $input == n ]
then
	exit
fi

}


validate_input
VMX_file=`vmware-cmd -H $VCenter --vihost $ESXHost -U $VCenter_User -P $VCenter_Pass -l | grep "$Host"`
vm_check_snapshot
sleep 60
power_off_vm
sleep 60
vm_backup
expand_vm_disk
sleep 120
power_on_vm

