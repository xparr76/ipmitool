#!/bin/bash
#
### Control fan speed
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sensor reading "Temp" "FAN1"	# print temps and fans rpms
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sdr get "FAN1" 		# print fan info
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x01 0x00       # enable manual/static fan control
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x01 0x01       # disable manual/static fan control
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x02 0xff 0x00	# set fan speed to 0 rpm
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x02 0xff 0x14	# set fan speed to 20 %
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x02 0xff 0x1e	# set fan speed to 30 %
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x02 0xff 0x64	# set fan speed to 100 %
#
### Show the sensor output:
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sdr type Temperature
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sdr elist full
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sdr get "Fan1"
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sdr list 
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sdr type list 
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sdr type Temperature
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sdr type Fan
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sdr type "Power Supply"
#
### Chassis commands:
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD chassis status
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD chassis status ipmitool chassis identify []	# turn on front panel identify light (default 15s) 
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD chassis power soft 				# initiate a soft-shutdown via acpi 
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD chassis power cycle 				# issue a hard power off, wait 1s, power on 
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD chassis power off 				# issue a hard power off 
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD chassis power on 				# issue a hard power on 
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD chassis power reset 				# issue a hard reset
#
### Modify boot device for the next reboot:
# ipmitool chassis bootdev pxe 
# ipmitool chassis bootdev cdrom 
# ipmitool chassis bootdev bios


IDRACIP=${1:-""}
IDRACUSER=${2:-""}
IDRACPASSWORD=${3:-""}
TEMPTHRESHOLD=${4:-"40"}
FANSPEEDMIN=${5:-"10"}
FANSPEEDMAX=${6:-"60"}
DELAY=${7:-"5"}
SENSORNAME="Temp"

echo "IP:" $IDRACIP
echo "User:" $IDRACUSER
echo "Tempthreshold" $TEMPTHRESHOLD
echo "FanMax %:" $FANSPEEDMAX
echo "FanMin %:" $FANSPEEDMIN
echo "Interval: " $DELAY

int_handler()
{
    logInfo "Interrupted"
	dynamicFanControl "on"
    # Kill the parent process of the script.
    kill $PPID
    exit 1
}
trap 'int_handler' INT

function logInfo() {
	local TIME=$(date +%Y-%m-%d-%H:%M:%S)
	local IP=$IDRACIP
	local MSG=$1
	echo "$TIME ip:${IP} fanspeed:${FANSPEED}% temp:${CURRENTTEMP}c last:${LASTTEMP}c ${MSG}" 2>&1 | tee -a /logs/ipmitool_$(date +%Y-%m-%d).log
}

function getCpuTemp() {
	local SENSORTEMPS=$(ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sdr type temperature | grep $SENSORNAME | cut -d"|" -f5 | cut -d" " -f2)
	IFS=" " read -ra ARRAY <<< "${SENSORTEMPS//$'\n'/ }"
	# ARRAY[0] = (Inlet Temp)
	# ARRAY[1] = (Exhaust Temp)
	# ARRAY[2] = (CPU 1 Temp)
	# ARRAY[3] = (CPU 2 Temp)
	
	# set highest temp cpu to CURRENTTEMP
	CURRENTTEMP=$(( ${ARRAY[2]} > ${ARRAY[3]} ? ${ARRAY[2]} : ${ARRAY[3]} ))
}

function dynamicFanControl(){
	FANCONTROL=${1:-on}
	if [[ $FANCONTROL = "on" ]] && [[ $LASTDYNFAN != "on" ]]; then
		LASTDYNFAN="on"
		logInfo "enable dynamic fan control"
		ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x01 0x01
	elif [[ $FANCONTROL = "off" ]] && [[ $LASTDYNFAN != "off" ]]; then
		LASTDYNFAN="off"
		logInfo "disable dynamic fan control"
		ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x01 0x00
	fi
}

function changeFanSpeed(){
	# convert fan speed value from dec to hex
	local HEXVALUE=$(printf "%x" $1)
	ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x02 0xff 0x$HEXVALUE
}

function fanUp(){
	FANSPEED=$(( ( $FANSPEED + 1 ) + ( $CURRENTTEMP - $LASTTEMP ) + ( ( $CURRENTTEMP - $TEMPTHRESHOLD ) / 5 ) ))
	changeFanSpeed $FANSPEED
}

function fanDown(){
	FANSPEED=$(( ( $FANSPEED - 1 ) - ( $LASTTEMP - $CURRENTTEMP )))
	changeFanSpeed $FANSPEED
}

while true
do
	# call ipmitool and return temps
	getCpuTemp
	
	# set LASTTEMP and FANSPEED on first run
	if [[ $LASTTEMP < 1 ]]; then 
		LASTTEMP=$CURRENTTEMP
		FANSPEED=$(($CURRENTTEMP-10))
		logInfo "Start"
	fi
	
	# only control fan speed if highest cpu temp is higher then threshold 
	if [[ $CURRENTTEMP > $TEMPTHRESHOLD ]]; then
		# disable dynamic fan control
		dynamicFanControl "off"
		
		# Increase or decrease a fan speed to match cpu temp changes
		if [[ $FANSPEED < $FANSPEEDMAX && $CURRENTTEMP > $LASTTEMP ]]; then
			logInfo "speed up fan"
			fanUp
			
		elif [[ $FANSPEED > $FANSPEEDMIN && $CURRENTTEMP < $LASTTEMP ]]; then
			logInfo "slow down fan"
			fanDown
			
		else
			logInfo "idle no change"
		fi
	else
		# enable dynamic fan control
		logInfo "idle dynamic state"
		dynamicFanControl "on"
	fi
	LASTTEMP=$CURRENTTEMP
	sleep $DELAY
done
