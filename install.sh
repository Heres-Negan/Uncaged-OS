#!/system/bin/sh

############ SET VARIABLES ############

PATH=/sbin:/system/bin:/system/xbin:/vendor:
export PATH=/sbin:/system/bin:/system/xbin:/vendor:

log='/data/local/tmp/uncaged.log'
install_dir='/sdcard/.android_containers'
root_dir='/'
count=1

############ END OF VARIABLES ############

############ START OF FUNCTIONS ############

# Top and Bottom Dividers.

DIVIDER_TOP() { 
	sleep 1
	echo "##################### [ $(date) ] ########################" | tee -a $log_input
	sleep 1
}

DIVIDER_BOTTOM() { 
	sleep 1
	echo "##################### [      Uncaged Install Log     ] ########################" | tee -a $log_input
	echo ""
	sleep 1
}

#The LOGGER function will take a command plus its args in and the path to alog file. It will check the exit status of the given command and exit the script and log the unsuccessful execution to the given log file. Passing a 3rd argument tells the logger not to exit after an error.Tthe 3rd argument can be any string but ill use -noexit 

LOGGER() {
	command_input=$1
	log_input=$2

	DIVIDER_TOP
	echo "***** Attempting to Execute CMD $command_input  *****" | tee -a $log_input

	$command_input >> $log_input
	exit_code=$?

	if [[ $exit_code = 0 ]]
    	then       
 	   	echo "***** CMD $command_input was Successfully Executed *****" | tee -a $log_input       
 	   	count=$((count +1))
        else       
     	   echo "***** CMD $command_input Failed with exit status $exit_code. *****" | tee -a $log_input
     	   count=$((count +1))
        if [ -z $3 ]
            then 
            exit 1
       fi
	fi
	
	DIVIDER_BOTTOM
}

#The PRO_STORAGE_CHECK function adds a check to make sure ProStorage is not installed. Support may be added at a later date. TBD

PRO_STORAGE_CHECK() {
    if [ -e /system/bin/estoraged ]
        then echo "***** This Application is not yet compatible with ProStorage. Aborting *****" | busybox tee -a $log
        exit 1
    fi
}

# The CHECK_BBOX function checks for a current Busybox install. It is easier for us to just install busybox everytime rather than add conditions. Install is Busybox 1.32

CHECK_BBOX() {
	LOGGER "mount -o remount,rw /system" $log
	rm /system/bin/busybox 2>/dev/null

	LOGGER "cp /data/local/tmp/uncaged/resources/busybox /system/xbin/busybox" $log
	LOGGER "chmod 777 /system/xbin/busybox" $log
	LOGGER "busybox --install /system/xbin" $log -noexit
}

# The CHECK_DEPENDS function tests for required programs availablity and exits if the required program is not found. the program name is the only argument

CHECK_DEPENDS() {
    program=$1
   
    DIVIDER_TOP
    
    echo "***** Checking for $program *****" | busybox tee -a $log
    
    type $program 2>&1 >> $log
        if [[ $? != 0 ]] 
        then 
            echo "***** Fatal Error. This script requires $program and it was not found in the current PATH  *****" | busybox tee -a $log
            exit 1
        fi
    DIVIDER_BOTTOM
}

#THE CHECK_SPACE function checks to make sure there is at least 8GB of space available on the sdcard for the images to be made.

CHECK_SPACE() {
    unset free_space
    if [ -z $(busybox df -m | busybox awk '/\/mnt\/sdcard/ {print $6}') ]
        then free_space=$(busybox df -m | busybox awk '/\/mnt\/sdcard/ {print $3}')
        else free_space=$(busybox df -m | busybox awk '/\/mnt\/sdcard/ {print $4}')
    fi
    required_space=800
    if [ $free_space -lt $required_space ]
        then echo "$(busybox date) ***** Fatal Error. Not enough space. This package requires $required_space MB for available space on the sdcard. *****" >> $log
        exit 1
    fi
}

#The COPY_PARTITION function creates and extracts a tar archive simultaneously. its essentially a recursive copy but we can pass arguments to exclude glob patterns from being copied over. plus i just trust tar more than cp to preserve mode and ownership when dealing with an entire partition.
	
	#The first argument $1 will be the target partition path, /sdcard for example
	#The second argument $2 will be the destination path

COPY_PARTITION() {
	cd $1
	DIVIDER_TOP
	busybox tar -cvf - ./* --exclude ./tiger --exclude tiger --exclude jpay --exclude Jpay --exclude com.android.battery --exclude 			"*latformI*" --exclude "*ettings.apk*" --exclude "*auncher*" --exclude "*attery*" --exclude "*com.mobilepearls.memory*" --exclude "*com.android.gallery3d*" --exclude "*com.android.music*" --exclude "*com.artifex.mupdfdemo*" --exclude "*com.lecz.android.tiltmazes*" --		exclude "*com.anpeco.xoxoxo*" | busybox tar -xC $2 -f -
	DIVIDER_BOTTOM
}

#The MAKE_EMPTY_SYSTEM_IMAGE and MAKE_EMPTY_DATA_IMAGE functions create a 4GB (Data) IMG and a 512MB (System) IMG of zeros to be formatted later.

MAKE_EMPTY_SYSTEM_IMAGE(){
	LOGGER "busybox dd if=/dev/zero of=$1 bs=1048576 count=512" $log
}

MAKE_EMPTY_DATA_IMAGE(){
	LOGGER "busybox dd if=/dev/zero of=$1 bs=1048576 count=4000" $log
}

#The FORMAT_IMAGE function creates a loop device associated with an img file and formats it as ext4. The first argument should be the loop device name to be created. the second argument is the block device minor. that can be any nuumber between 1 and 255. mke2fs will require you to awnser a y/n prompt if you use it on an image file instead of a block device. so were just working around that by creating a loop device associated with our file and then formatting the loop device with mke2fs

FORMAT_IMAGE() {
    LOGGER "busybox mknod /dev/block/$1 b 7 $2" $log -noexit
    LOGGER "busybox losetup /dev/block/$1 $install_dir/$1.img" $log
    LOGGER "/sbin/mke2fs -T ext4 -m 1 /dev/block/$1" $log 
}

# The EXTRACT function extracts a tar.xz archives to the given directory of the new System and Data images.

	#The first argument $1 will be the target
	#The second argument $2 will be the destination path

EXTRACT() {
	busybox xzcat $1 | busybox tar -xvC $2 -f -
}

#The FLASH_BOOT2RECOVERY function rips the currently installed boot.img and flashes it over the recovery img we can use this to our benefit later by adding a check to see which slot was booted and execute code based on boot slot. This will allow us to boot to uncaged using recovery boot.

FLASH_BOOT2RECOVERY() {
	LOGGER "busybox dd if=/dev/block/mtd/by-name/boot of=/dev/block/mtd/by-name/recovery" $log
}

############ END OF FUNCTIONS ############

############ START OF INSTALLATION ############
############ UP TO NOW NOTHING HAS BEEN EXECUTED ############
    
    PRO_STORAGE_CHECK
    
    LOGGER 'mount -o remount,rw /' $log -noexit
    LOGGER 'mount -o remount,rw /system' $log -noexit
    
    CHECK_BBOX
    CHECK_DEPENDS mke2fs
    CHECK_DEPENDS mount
    CHECK_DEPENDS chown
    CHECK_DEPENDS chmod
    CHECK_SPACE
    
    if [ ! -d $install_dir ]
    	then LOGGER "mkdir $install_dir" $log -noexit 
    fi
    
    MAKE_EMPTY_SYSTEM_IMAGE "$install_dir/jpu.img"
    MAKE_EMPTY_DATA_IMAGE "$install_dir/data.img"
    
    FORMAT_IMAGE 'jpu' "123"
    FORMAT_IMAGE 'data' "246"
    
    LOGGER 'mkdir /mount' $log -noexit
    LOGGER 'mkdir /mount/jpu' $log -noexit
    LOGGER 'mkdir /mount/data' $log -noexit
    
    LOGGER "busybox mount -t ext4 $install_dir/jpu.img /mount/jpu" $log
    LOGGER "busybox mount -t ext4 $install_dir/data.img /mount/data" $log
    
    COPY_PARTITION '/system' '/mount/jpu'
    COPY_PARTITION '/data' '/mount/data'
    
    LOGGER "rm -r /mount/data/dalvik-cache/*" $log -noexit
    
    #extracting jpu files into our new system container
    EXTRACT /data/local/tmp/uncaged/resources/jpu_system_apps.tar.xz /mount/jpu/app
    EXTRACT /data/local/tmp/uncaged/resources/jpu_framework.tar.xz /mount/jpu/framework
    
    #Copying the new mkshrc to spruce up the shell.
    LOGGER 'cp /data/local/tmp/uncaged/resources/mkshrc /mount/jpu/etc/' $log -noexit
    
    #Unmounting the new containers.
    cd $root_dir
    LOGGER 'busybox umount /mount/jpu' $log -noexit 
    LOGGER 'busybox umount /mount/data' $log -noexit
    
    FLASH_BOOT2RECOVERY
    
    #Copying new jpayinit.sh and setting the appropriate permissions.
    LOGGER "cp /data/local/tmp/uncaged/resources/jpayinit.sh /system/bin/jpayinit.sh" $log -noexit
    LOGGER "chmod 777 /system/bin/jpayinit.sh" $log -noexit
    LOGGER "chown root:root /system/bin/jpayinit.sh" $log -noexit
    
############ END OF INSTALLATION ############
