# EXTREME ANDROID LAUNCHER

This is a script I created whil trying to unit test my apps.

This will work on any system with Bash 4.

Feel free to add feature requests and/or suggestions.

## USAGE

extreme-android-launcher.sh -{l} -{i} - {a} - {t} - {z} - {d} - {c} - {v} - {k} - {r} - {w} - {t} - {c} - {e} - {h} avdname--- Script to Launch Android Emulators

where:

	-l		launch an AVD with name (skips logging and cleanup)
	-i		install an app from apk (from the sdcard)
	-a		launch an app activity (specify the activity name)
	-t		pass text to the app
	-z		send some keys to clear the screen (i.e. before an activity launch)
	-d		check out debug logs
 	-c		clear logs
	-v		get available AVD's
	-k		kill running emulators
	-r 	 	list running emulators
	-w		visual mode (for debugging)
	-e		some examples
	-h		display help

Specify an AVD to launch at runtime
Use the -a option to get available AVD's
Only 1 instance of an AVD can run at a time

All other parameters are optional

MAKE SURE TO ADD ANDROID_HOME TO YOUR PATH, THIS SCRIPT DEPENDS ON TOOLS BEING THERE
