#!/bin/bash

# Total count of local files
total_inodes=$(df -P --local --inodes --total | tail -1 | awk '{print $3}')

# Estimated total space required
space_budget=$((total_inodes*200))

# Find filesystems containing space budget folders
paths=(/ /tmp /var)
declare -A fs avail
for path in ${paths[@]}; do
  fs[$path]=$(df -P $path | tail -1 | awk '{print $6}')
  avail[$path]=$(df -P -B1 $path | tail -1 | awk '{print $4}')
done

# Spend space budget
for path in ${paths[@]}; do
  avail[${fs[$path]}]=$((${avail[${fs[$path]}]}-space_budget))
done

# Report shortfalls, if any
for path in ${paths[@]}; do
  if [[ ${avail[$path]} -lt 0 ]]; then
    cat <<-EOF
	DANGER!
	Not running pre-upgrade because of filesystem exhaustion risk. Based on
	inode count of $total_inodes, there may not be enough space available in
	the $path filesystem. Make more space available or bypass filesystem
	capacity checks at your own risk.
	EOF
    ((badinitio++))
  fi
done

exit $badinitio
