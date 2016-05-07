#!/bin/bash

# Script to launch android emulators

# TODO: Auto close activities in the way of a launched app
# TODO: Verify install

# This script logs for this specific run and can work with an infinite number of avd's. However, only one instance of each avd can be running at a time

# HEADS UP : Bash 4 on OSX will probably be installed to a different path

# Script requires Bash 4
bashversion=$(bash --version | head -n 1 | awk '{print $4}')
if [[ $bashversion != 4* ]]; then
	echo "Requires Bash 4. Check your shell and try again"	
	exit
fi

function usage {
	echo "$(basename "$0") -{l} -{i} - {a} - {t} - {z} - {d} - {c} - {v} - {k} - {r} - {w} - {t} - {c} - {e} - {h} avdname--- Script to Launch Android Emulators"
	echo "where: " 
	echo "	-l		launch an AVD with name (skips logging and cleanup)"
    	echo "	-i		install an app from apk (from the sdcard)" 
    	echo "	-a		launch an app activity (specify the activity name)"
	echo "	-t		pass text to the app"
    	echo "	-z		send some keys to clear the screen (i.e. before an activity launch)"
	echo "	-d		check out debug logs"	
	echo " 	-c		clear logs"
    	echo "	-v              get available AVD's"
	echo "	-k		kill running emulators"	
	echo "	-r 	 	list running emulators"
    	echo "	-w		visual mode (for debugging)"
    	echo "	-e		some examples"
    	echo "	-h		display help"
    	echo
    	echo "Specify an AVD to launch at runtime"
    	echo "Use the -a option to get available AVD's" 
    	echo "Only 1 instance of an AVD can run at a time"
    	echo
    	echo "All other parameters are optional" 
    	echo
    	warning="Make sure to add ANDROID_HOME to your PATH, this script depends on tools being there"
    	echo "${warning^^}"
    	echo
    	exit 1
}

function examples {
	echo "------------- EXAMPLES -----------------"
    	echo
    	echo "Install an app:"
    	echo -e "\t $(basename "$0") -i myapp.apk MyAVD"
    	echo "Launch an app:"
    	echo -e "\t $(basename "$0") -a myapp.activity MyAVD"
    	echo "Install and Launch:"
    	echo -e "\t $(basename "$0") -a myapp.activity -i myapp.apk AnyAVD"
    	exit
}

#####----------------------------FUNCTIONS ------------------------------#####

# List available AVDs
function listavds {
	android list avd
	if [ $? -eq 127 ]; then
		echo -e "\nANDROID_HOME is not in your path...this is a courtesy warning\n"
		usage
	fi	
}

# List running emulators
function listemu {
        ps -ef | grep '[e]mu'
	if [ $? -eq 1 ]; then
		echo "No old emulators found"
	else
		ps -ef | grep '[e]mu' | awk '{print $2}'
	fi
}


# Kill all running emulators - for debug purposes
function killemu {
	oldness=$(listemu)
	if [[ $oldness == No* ]]; then
		echo $oldness
	else
		kill -9 $oldness > /dev/null 2>&1
	fi
}


# Dump activities to debug log
function activitydump {
	echo "--------------- $1 ----------------" >> $debuglog	
	echo >> $debuglog
	adb shell dumpsys activity activities | grep -i run >> $debuglog 2>&1
}

# Select instance to debug
function selectdebug {
	count=$(ls -l $outputdir | wc -l)	
	if [ $count -gt 1 ]; then
		select DIRNAME in $outputdir/*; do
			if [ -z $DIRNAME ]; then
				echo "Quitting"
			else
				echo "You picked $DIRNAME ($REPLY)"
				more "$DIRNAME/debug.log"
			fi
			exit
		done
	else
		echo "There are no files there"
	fi	
}

# Clear instance loggs
function clearlogs {
	rm -rf $outputdir/* > /dev/null 2>&1
	rm -rf /tmp/* > /dev/null 2>&1
}

# Kill everything
function cleanup {
	# Get the emulator PID from file
	echo "Killing emulator with $PID"	
	kill -9 "$PID"
}

# Launch the emulator
# Save the PID of the parent process to kill later
function launchit {
	echo "Launching the emulator and waiting for it come up"	
	adb start-server	
	# Base emulator switches
	switches="-wipe-data -no-audio -verbose"
	# Windowed emulator
	if [ -z $windowed ]; then
		switches="$switches -no-skin -no-window"	
	fi	
	# Checking the OS version - MAC doesn't support kvm (which helps in linux)
	unamestr=$(uname)
	if [[ "$unamestr" != *Darwin* ]]; then
		switches="$switches -qemu -enable-kvm"
	fi	

	# No frills launch with switch
	if [ ! -z $lavd ]; then
		echo "Starting the emulator with AVD named: $lavd"	
		switches="-avd $lavd $switches"
		emulator $switches
		exit
	fi
	
	echo "Starting the emulator with AVD named: $1"	
	switches="-avd $1 $switches"
	emulator $switches > $avdlog 2>&1 &	
	
	PID=$!
	echo
	sleep 30
	# Need to get the name of the emulator for adb
	devices=$(adb devices | grep emulator | wc -l)
	port=$(grep "listening on port" "$avdlog" | sed 's/[,].*$//' | sed 's/.*port//' | tr -d ' ')
	devicename="emulator-$port"
	if [ ! -z $port ]; then	
		echo "Looking for $devicename"	
		# Need to make sure that the device is actually coming up
		if ! adb devices | grep -w $devicename  > $scriptlog 2>&1; then
        		echo "Didn't start...exiting"
			cleanup
       			exit 1
		else
			echo "Device started"
			echo
		fi
	else
		echo "Error reading the device log...something probably went wrong"	
		cleanup
		exit 1
	fi
	echo "Waiting for the device to come up"
	until adb devices | grep -w "$devicename" | grep -qw device; do
		echo  "Waiting..."
		sleep 10
	done
}


# Install an app from APK
function installit {
	echo "Installing an app"	
	echo "My devicename is $devicename: using it to install" >> $scriptlog	
	# Make sure the apk is on the sdcard
	if [ $(adb -s $devicename shell 'ls /mnt/sdcard/$apk > /dev/null 2>&1; echo $?') == "1" ]; then
		echo "Package needs to be on the root of the sdcard"
		echo "Use ADB shell to put it there"
		cleanup
		exit
	fi
	i=0
	while [[ $(adb -s $devicename shell pm install "/mnt/sdcard/$apk") == *"Package"* ]]; do
        	echo "Package Manager not avialable...wait for a bit"
        	sleep 15
		i=$[$i+1]
        	if [ $i == 10 ]; then
			echo "Device is not available...exiting"
                	cleanup
                	exit
        	fi	
	done

	echo "Package successfully intalled"
	echo	

	# Activties dump for debugging
        activitydump "Installed"
}

function verifyinstall {
	# Verify install
	echo "Verifying install"
	adb -s $devicename shell pm list packages | grep app >> $scriptlog 2>&1
	if [ $? -eq 0 ]; then
        	echo "Package successfully installed"
		echo
	else
        	echo "Package failed to install"
        	cleanup
        	exit
	fi
	
	# Activties dump for debugging
	activitydump "Verified Installed"
}

function intheway {
	echo "Send returns is in case junk in the way"	
	# Sending starter keys in case something is in the way of the app
	sleep 1
	adb -s $devicename shell input keyevent 66
	sleep 1
	adb -s $devicename shell input keyevent 66
	if [ $? -eq 0 ]; then
                echo "Keys sent...stuff cleared"
		echo
        else
                echo "Something went wrong"
		cleanup
		exit 1
        fi
	
        # Activties dump for debugging
        activitydump "In the Way"
}

function launchapp {
	echo "Launching an app activity"
	# ADB doesn't return error codes - grepping output
	adb -s $devicename shell am start -d -W -n $activity >> $scriptlog 2>&1
	if grep -q "unable to resolve Intent" $scriptlog; then
        	echo "Something went wrong"
		cleanup
		exit 1
	else
        	echo "Installed Correctly"
		echo
	fi

	# Activties dump for debugging
        activitydump "Launched App"
}

function sendkeys {
	# Send keys to enter text
	sleep 5
	echo "Sending somme keys"
	sleep 1
	adb -s $devicename shell input text $apptext
	if [ $? -eq 0 ]; then
		echo "Text sent...on my way"
	else
		echo "Something went wrong"
		cleanup
		exit 1
	fi
	sleep 1
	adb -s $devicename shell input keyevent 61
	sleep 1
	adb -s $devicename shell input keyevent 66
	sleep 1
	adb -s $devicename shell input keyevent 66
	sleep 1
	adb -s $devicename shell input keyevent 66
	if [ $? -eq 0 ]; then
        	echo "Keys sent...looking good"
		sleep 5
		echo
	else
        	echo "Something went wrong"
		cleanup
		exit 1
	fi
	
	# Activties dump for debugging
        activitydump "Keys Sent"
}

#####----------------------------- END FUNCTIONS --------------------------#####



#####-------------------------------- GET OPTS ----------------------------#####

options='l:i:a:t:zdcvkrweh'
while getopts $options option; do
	case $option in
		l  ) lavd=$OPTARG;;
		i  ) apk=$OPTARG;;	
            	a  ) activity=$OPTARG;;
		t  ) apptext=$OPTARG;;
		z  ) clearscreen="YES";;
	    	d  ) selectdebug;exit;;	
		c  ) clearlogs;exit;;
	    	v  ) listavds;exit;;
		k  ) killemu;exit;;
	    	r  ) listemu;exit;;
	    	w  ) windowed="YES";;
		e  ) examples;exit;;
            	h  ) usage;exit;;
            	\? ) echo -e "Illegal Option\n";usage;exit;;
    esac
done

shift $(($OPTIND - 1))

#####--------------------------END FUNCTIONS ------------------------------#####

## REQUIRED - end here ##
##

if [ -z $1 ] && [ -z $lavd ]; then
	echo "Please add the AVD name"
	usage
fi

# Make sure no other instances of this AVD are running
if ps -ef | grep emulator | grep -qw $1; then
        echo "Only one instance running at a time"
        exit
fi

#####--------------------------DECLARE VARIABLES ------------------------------#####

# Crete the masterpid as a marker for the children
MASTERPID=$$

DATE=`date +%m%d-%H.%M-`

avd="$1"

# Logging
outputdir="$HOME/myapp/output"
output="$outputdir/$DATE$MASTERPID"
avdlog="$output/avd.log"
scriptlog="$output/script.log"
debuglog="$output/debug.log"
mkdir -p $output
touch $debuglog

#####--------------------------END VARIABLES ------------------------------#####

echo "Started at: $(date)"

# Launch the emulator
launchit $1
echo "Device available at: $(date)"

## Do various things

# Install an app
if [ ! -z $apk ]; then
	installit	
fi

# Clear the screen
if [ ! -z $clearscreen ]; then
	intheway
fi

# Launching an app
if [ ! -z $activity ]; then
	launchapp
fi

# Sending text to an app
if [ ! -z $apptext ]; then
	sendkeys
fi

# Finally, cleaning house
cleanup
echo "Finished at: $(date)"
