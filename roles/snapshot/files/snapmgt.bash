#!/bin/bash
#
# Script: snapmgt.bash
#
# This script will manage rootvg LVM snapshots.  Createsnaps, Deletesnaps, and Revert
# 
# This is intended to be around the Leapp upgrade method
#
# Challenge: create a script to create an OS snapshot for all LVs on a system.
# Include removal and status check of any RootVG snapshots
#
# Extras: 
# use exit codes to signal to Ansible facts about the state.( no snaps, have snaps etc)
# add stanza to extend RootVG with a known or discovered LUN
#
# Semanics: 
# /dev/mapper/rhel-lvvar and /dev/rhel/lvvar are both symlinks to /dev/dm-2
#
# Will use /dev/rhel/lvvar format
# Will collect all ROOTLVS from OS, and then subtract out those that correspond to the 
# file systems listed in the exclude list
# 
# Deletesnaps and revert will only act on snaps that exist, no tuning there.

usage() {
echo "
Usage: $0
  status - show status of snaps on the system
  createsnaps - create snaps of all LVs in RootVG
  revert - Revert to original OS - merge any snaps back in
  deletesnaps - Accept upgraded OS, delete any point-in-time copies

Export variables for additional snapshot size control
  LVPERCENT    Controls the percentage of the original LVsize (1-115)
  LVMAXMB      Max size in MB for any LV ( 4000 set max snapshot to 4GB)
  Debug	       extra printed hints along the way (export debug true to enable)
"
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

dprint(){
[[ $DEBUG == "true" ]] && echo $@
}

[[ -z $DEBUG ]] && DEBUG="false"

# List of filesystems to NOT snapshot
SKIPFS="/var/tmp /opt/abc /var/junk/junk /var/cache /var/lib/leapp"

# Other Pre-Checks go here.

case $1 in
createsnaps) 

     echo "Cleanup of /var/lib/leapp"
     # identify RootVG
     findrootvg
     dprint "$ROOTVG has free $FREE MB"

     # Do Snaps exist already? 
     ROOTVGSNAPCOUNT=`lvscan | grep $ROOTVG | grep Snapshot | wc -l`
     if [[ $ROOTVGSNAPCOUNT -gt 0 ]]; then
        echo "There are already $ROOTVGSNAPCOUNT snapshots active in rootvg."
        lvscan | grep $ROOTVG | grep Snapshot
        echo "Can't create new snapshots. Exiting"
        exit 10
     fi 

     dprint "Emptying yum and dnf cache"
     yum clean all
     dnf clean all

     dprint "Cleaning up /var/lib"

     # If /var/lib/leapp is a Symlink and its good, accept it, otherwise redo.
     if [[ -L /var/lib/leapp ]] && [[ -e /var/lib/leapp ]]; then
           echo "Destination for leapp payload is set to `file /var/lib/leapp`"
         else
           echo -e "Setting up /var/lib/leapp -> /var/tmp/leap\n"
           rm -rf /var/lib/leapp > /dev/null 2>&1
           rm -rf /var/tmp/leapp > /dev/null 2>&1
           mkdir /var/tmp/leapp
           ln -s /var/tmp/leapp /var/lib/leapp
     fi

     dprint "empty out /var/lib/leapp"
     COUNT=`find /var/lib/leapp/ -maxdepth 1 | wc -l`
     if [[ $COUNT -gt 1 ]]; then
          rm -rf /var/lib/leapp/*
     fi

     dprint `file /var/tmp/leapp`
     dprint `file /var/lib/leapp`

    echo "Free space check"
    THRESHOLD=4500
    for FS in /tmp /var/tmp; do
              [[ ! -d $FS ]] && continue
              FREE=`df --output=avail -hm $FS | tail -1 | awk '{ print $1 }'`
       if [[ $FREE -lt $THRESHOLD ]]; then
              echo "Insufficient space in $FS: $FREE MB. Please add or free up space to get above $THRESHOLD available"
              exit 11
       fi
     done

     # Add check if percentage of free VG is OK?
     
     dprint "Adjust size limits and percentage values"
     ## Set Snap-Create-Percentage - default 100% size
     # LVPERCENT is the percentage of the LV SIZE
     LVPERCENT="${LVPERCENT:=100}"
     echo "== Snap volumes to be created at ${LVPERCENT}% =="

     # SIZE is max size for snapshot - default 6GB
     LVMAXMB="${LVMAXMB:=6000}"
     echo "== Snap volumes Max size at ${LVMAXMB}MB =="

     findrootlv
     
     dprint "Identify which file systems to skip"

     for FS in $SKIPFS; do
        # does it exist?
        dprint "Skip candidate: $FS"
        if [[ ! -x $FS ]]; then
           dprint "No such dir $FS"
           continue
        fi
     
        # is it a file system?
        ITSFS=`df $FS | tail -1 | awk '{print $NF}'`
        if [[ $FS != $ITSFS ]]; then
           dprint "$FS is not a file system boundary"
           continue
        fi
     
        # determine its /dev/mapper/VG-LV name
        MAPNAME=`df $FS 2>/dev/null | tail -1 | awk '{ print $1}'`
        # Determin its /dev/VG/LV name
        DVLNAME=`lvdisplay $MAPNAME | grep "LV Path" | awk '{ print $3 }'`
     
        echo  "## Exclude $DVLNAME ##"
        EXCLUDEFS=${EXCLUDEFS}" $DVLNAME"
     done
     
     echo "Removing excluded LVs from the todo list"
     ROOTLVSREAL=$(comm -23 <(tr ' ' '\n' <<<"$ROOTLVS" | sort -u ) <(tr ' ' '\n' <<<"$EXCLUDEFS" | sort))

     echo -e "LVS on local system:  \n$ROOTLVS"
     echo -e "Skip List  : \n$SKIPFS"
     echo -e "LVs to snap: \n$ROOTLVSREAL"

     # Save copy of /boot
     [[ ! -d /root/boot-safe/ ]] && mkdir /root/boot-safe
     echo "Saving copy of the files in /boot"
     rsync -Wa /boot/ /root/boot-safe  --delete
     
     # SIZE is used to collect the criteria for snapshot size. 
     # Define LVPERCENT or accept 100% as default LV snapshot SIZE
     for LV in $ROOTLVSREAL; do
       SNAPNAME=`echo $LV | awk -F/ '{ print $NF }'`
       SIZE=`df -hm $LV --output=size | tail -1 | awk '{ print $1 }'`
       echo "=== LV $LV found with size: ${SIZE}MB ==="
       SIZE=$(( $SIZE * LVPERCENT / 100 ))
       if [[ $SIZE -gt $LVMAXMB ]]; then
           SIZE=${LVMAXMB}
           echo "  !! Max LV size for $LV capped at ${LVMAXMB}MB !!"
       fi
       echo "  Creating snapshot of $LV with size $SIZE"
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
     LVUSAGE=0
     for LV in $ROOTLVS; do
        LVUSED=`df -m $LV | awk '{print $3}'|tail -1`
        echo "LV $LV uses $LVUSED MB"
        LVUSAGE=$(( LVUSAGE + LVUSED ))
     done
     echo "Storage used by all LVs: $LVUSAGE MB"

     echo "Checking /boot copy:"

     if [[ -d /root/boot-safe ]]; then
          echo "We have a copy of the boot directory"
        else
          echo "No boot directory found for revert/rollback"
     fi
     echo -e "\n Status of first 2 bootable kernels in order: "
     grubby --info=ALL | grep kernel | head -4
     echo -e "\nDefault kernel to boot from: "
     grubby --default-kernel
     ;;

revert)
     echo "Rollback/revert OS to previous version"
     # list out current snapshot
     # convert/merge to original
     findrootvg
     findrootlv

     # Do Snaps exist?
     ROOTVGSNAPCOUNT=`lvscan | grep $ROOTVG | grep Snapshot | wc -l`
     if [[ $ROOTVGSNAPCOUNT -eq 0 ]]; then
        echo "There are no snapshots active in rootvg. Exiting "
        exit 13
     fi


     for LV in $SNAPLVS; do
       echo "Rolling back $LV into its parent"
       lvconvert --mergesnapshot $ROOTVG/$LV
     done

     # Restore boot dir remove upgrade kernel # Check for existance, size/sanity
     rsync -Wa /root/boot-safe/ /boot --delete
     if [[ -f /boot/vmlinuz-upgrade.x86_64 ]]; then
        echo "Removing pre-reboot kernel"      
        grubby --remove-kernel=/boot/vmlinuz-upgrade.x86_64
     fi


     DEFKERNEL=`grubby --default-kernel | grep vmlinuz-4`
     
     COUNT=`echo $DEFKERNEL | grep vmlinuz-4 | wc -l`
     if [[ $COUNT -gt 0 ]]; then
        grubby --remove-kernel=$DEFKERNEL
     fi

     BOOTSECTORPLACE=`echo /dev/$(basename $(readlink -f /sys/class/block/$(basename $(df /boot | grep -o '^/[^ ]*'))/..))`
     grub2-install $BOOTSECTORPLACE

     ;;

deletesnaps)  # Roll
     echo "Delete snaps of the OS"
     findrootvg
     findrootlv
     ROOTLVSNAPS=`lvs --noheadings $ROOTVG -S 'lv_attr =~ ^s' | awk '{ print $1 }'`
     if [[ $ROOTLVSNAPS == "" ]]; then
        echo "No snaps found in Volume Group: $ROOTVG"
        exit 15
     fi
     for ROOTLVSNAP in $ROOTLVSNAPS; do
         lvremove -y /dev/$ROOTVG/$ROOTLVSNAP
     done
     ;;
*) 
     usage
     exit
     ;;
esac


