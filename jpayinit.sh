#!/system/bin/sh

PATH=/sbin:/system/bin:/system/xbin:/vendor
export PATH=/sbin:/system/bin:/system/xbin:/vendor
start vold

mount -t vfat /dev/block/vold/"31:10" /mnt/sdcard


while [[ $? != 0 ]]
do
    mount -t vfat /dev/block/vold/"31:10" /mnt/sdcard
done    

if [ -b /dev/block/mtdblock10 ]
	then 
	busybox mount -t ext4 /mnt/sdcard/.android_containers/data.img /data
	busybox mount -t ext4 /mnt/sdcard/.android_containers/jpu.img /system
	while [[ $? != 0 ]]
		do 
			busybox mount -t ext4 /mnt/sdcard/.android_containers/data.img /data
			busybox mount -t ext4 /mnt/sdcard/.android_containers/jpu.img /system
        done
	#stop zygote && start zygote
	start sdcard
	chmod 777 /mnt/sdcard
    chown root:sdcard_rw /mnt/sdcard
	sleep 10
fi

setprop persist.sys.usb.config mtp,adb
setprop service.adb.tcp.port 5555
stop adbd
start adbd
start tigerd
