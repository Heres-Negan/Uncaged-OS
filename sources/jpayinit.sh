#!/system/bin/sh

PATH=/sbin:/system/bin:/system/xbin:/vendor
export PATH=/sbin:/system/bin:/system/xbin:/vendor


#create a mount point for the early mount of our sdcard.

# the problem we're attempting to solve here
# is that our data and system containers are located on the sdcard. The sdcard is always the last block device
# to mount. as we're waiting for the sdcard so me can mount our containers over the actual data and system,
# some system apps start to initialize, the javaplatforminterface for example. It should only exist when we boot
# from stock. but if we don't get the jpu image mounted quick enough it will load. Then it will crash when we 
# do finally get our containers mounted


mount -o remount,rw /
mkdir /early_sd_mnt

#make it so only root can see it
chown root:root /early_sd_mnt
chmod 700 /early_sd_mount

# /dev/block/mtdblock9 on a normal system
#however booting from the recovery slot actually changes
# the mtd block numbers. it is preferable to refer to device blocks through the
#mtd/by-name #directoryall is the sdcard also 

mount -t vfat /dev/block/mtd/by-name/user /early_sd_mount


# this loop will check the exit status of the last command represented
# the special shell variable $?.  0 means the last command
# executed without error. 1 means it failed somehow.
# so this loop will repeat our mount command until it is successful
# the reason for this is that we don't know the exact time that our mtdparts
# become available mounting. we could sleep but instead
# why not just run the command thousands of times per second until it works
# this gives us the earliest possible mount

while [[ $? != 0 ]]
  do mount -t vfat /dev/block/mtd/by-name/user /early_sd_mount
done    

#   ( -b ) says if mtdblock10 is a block device
# since it only exists when we boot from the recovery slot 
# its basically a boot slot check to make a decision later

if [ -b /dev/block/mtdblock10 ]
  then busybox mount -t ext4 /early_sd_mnt/.android_containers/data.img /data
    while [[ $? != 0 ]]
      do busybox mount -t ext4 /early_sd_mnt/.android_containers/data.img /data
    done
   
  busybox mount -t ext4 /early_sd_mnt/.android_containers/jpu.img /system
    while [[ $? != 0 ]]
      do busybox mount -t ext4 /early_sd_mnt/.android_containers/jpu.img /system
	done

sleep 10 #this maybe unnecessary. we should check on this later
fi

setprop persist.sys.usb.config adb
setprop service.adb.tcp.port 5555
stop adbd
start adbd

# leaving off for now. check later to see if it affects anything

#start tigerd 
