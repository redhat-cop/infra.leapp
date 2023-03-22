#!/bin/bash
#
# Script: snapmgt.bash
#
# This script will manage rootvg LVM snapshots.  Createsnaps, Deletesnaps, and Revert
# 
# This is intended to be around the Leapp upgrade method
#
# Non-thin LV creation: 
# lvcreate --snapshot --size $SIZE --name $SNAPNAME /dev/$VG/$SRCLV
# 
# To create thin, omit the size arg
#
# Remove a snap (accept os update, and move on)
# lvremove $VG/$SNAPNAME
#
# Revert to an existing OS Snap
# lvconvert --merge $VG/$SNAPNAME
#
# Challenge: create a script to create an OS snapshot for all LVs on a system.
# Include removal and status check of any RootVG snapshots
#
# Extras: 
# use exit codes to signal to Ansible facts about the state.( no snaps, have snaps etc)
# add stanza to extend RootVG with a known or discovered LUN
#
# To see dump of all lvdisplay commands: 
# lvdisplay -C -o " " 
# lvdisplay --units m -C -o "lv_path,lv_dm_path"
#  
# To see lots of good storage information about a VG: 
# lvdisplay -m $VGNAME 
# lvdisplay --configreport vg 
# lvdisplay -m (lvname)

usage() {
echo "Usage: $0
  status - show status of snaps on the system
  createsnaps - create snaps of all LVs in RootVG
  revert - Revert to original OS - merge any snaps back in
  deletesnaps - Accept upgraded OS, delete any point-in-time copies"
exit
}

# -- Confirm name of the VG that owns /
findrootvg() {
ROOTVG=`df -hP / | tail -1 | awk '{ print $1 }' | cut -f4 -d\/ | cut -f1 -d-`
FREE=`vgdisplay $ROOTVG --units m | grep Free | awk '{ print $7 }'`
}

# -- Create list of all LVs in $ROOTVG, identify sum of all data usage in all LVs
findrootlv() {
ROOTLVS=`lvscan | grep $ROOTVG | grep -v Snapshot | cut -f2 -d\'| grep -v swap`
SNAPLVS=`lvs --noheadings $ROOTVG -S 'lv_attr =~ ^s' | awk '{ print $1 }'`
}

case $1 in
createsnaps) 
     echo "Creating Snapshot volumes"
     # id RootVG
     findrootvg
     echo "$ROOTVG has free $FREE MB"
  
     # percentage of free is OK?

     # Do Snaps exist? 
     ROOTVGSNAPCOUNT=`lvscan | grep $ROOTVG | grep Snapshot | wc -l`
     if [[ $ROOTVGSNAPCOUNT -gt 0 ]]; then
        echo "There are already $ROOTVGSNAPCOUNT snapshots active in rootvg."
        lvscan | grep $ROOTVG | grep Snapshot
        echo "Can't create new snapshots. Exiting"
        exit 10

     fi 
     findrootlv
     
     SIZE="4500m"

     for LV in $ROOTLVS; do
       SNAPNAME=`echo $LV | awk -F/ '{ print $NF }'`
       lvcreate -s -L $SIZE -n pre_upgrade_$SNAPNAME $LV
     done
     ;;

status)
     findrootvg
     findrootlv

     echo -e "LVs in root VG $ROOTVG: \n$ROOTLVS\n"
     echo -e "Active snaps in $ROOTVG:\n$SNAPLVS\n"
     echo "Status of Existing snaps on host:`uname -n`"
     lvs -S 'lv_attr =~ ^s'
     echo -e "\nOperational status of Root LVs on the system"
     lvdisplay --units m $ROOTVG -C -o "lv_path,lv_dm_path,origin_size,data_percent,snap_percent"
     echo -e "\nStorage Consumption of Root LVs on the system" 
     for LV in $ROOTLVS; do
        LVUSED=`df -m $LV | awk '{print $3}'|tail -1`
        echo "LV $LV uses $LVUSED MB"
        LVUSAGE=$(($LVUSAGE + $LVUSED))
     done
     echo "Storage used by all LVs: $LVUSAGE MB"
     ;;

revert)
     echo "Rollback/revert OS to previous version"
     # list out current snapshot
     # convert/merge to original
     findrootvg
     findrootlv

     for LV in $SNAPLVS; do
       echo "Rolling back $LV into its parent"
       echo "lvconvert --mergesnapshot $ROOTVG/$LV"
     done
     ;;

deletesnaps)  # Roll
     echo "Delete snaps of the OS"
     findrootvg
     findrootlv
     ROOTLVSNAPS=`lvs --noheadings $ROOTVG -S 'lv_attr =~ ^s' | awk '{ print $1 }'`
     for ROOTLVSNAP in $ROOTLVSNAPS; do
         lvremove -y /dev/$ROOTVG/$ROOTLVSNAP
     done
     ;;
*) 
     usage
     exit
     ;;
esac




#lvdisplay -C -o lv_path,lv_dm_path
#  Path               DMPath                   
#  /dev/rhel/lvvar    /dev/mapper/rhel-lvvar   
#  /dev/rhel/root     /dev/mapper/rhel-root    
#  /dev/rhel/rootsnap /dev/mapper/rhel-rootsnap
#  /dev/rhel/swap     /dev/mapper/rhel-swap    
#  /dev/rhel/varsnap  /dev/mapper/rhel-varsnap 
