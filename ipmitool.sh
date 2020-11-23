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
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sdr elist full                                # To See Only the Temperature, Voltage, and Fan Sensors
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sdr elist                                     # All sensors
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sdr get "Fan1"
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sdr type list
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sdr type Temperature
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sdr type Fan
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sdr type "Power Supply"
#
### Chassis commands:
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD chassis status
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD chassis status ipmitool chassis identify []   # turn on front panel identify light (default 15s)
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD chassis power soft                            # initiate a soft-shutdown via acpi
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD chassis power cycle                           # issue a hard power off, wait 1s, power on
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD chassis power off                             # issue a hard power off
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD chassis power on                              # issue a hard power on
# ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD chassis power reset                           # issue a hard reset
#
### Modify boot device for the next reboot:
# ipmitool chassis bootdev pxe
# ipmitool chassis bootdev cdrom
# ipmitool chassis bootdev bios

IDRACIP=${1:-""}
IDRACUSER=${2:-""}
IDRACPASSWORD=${3:-""}
TEMPTHRESHOLD=${4:-"40"}
FANSPEEDMIN=${5:-"20"}
FANSPEEDMAX=${6:-"40"}
DELAY=${7:-"5"}
FIRSTRUN="true"

int_handler()
{
    logInfo "WARN" "Interrupted"
	dynamicFanControl "on"
    # Kill the parent process of the script.
    kill $PPID
    exit 1
}
trap 'int_handler' INT

function logInfo() {
	local TIME=$(date +%Y-%m-%d-%H:%M:%S)
  echo $TIME $1 $2 2>&1 | tee -a /logs/ipmitool_$(date +%Y-%m-%d).log
}

function getSensors() {
  # first run setup
	if [[ $FIRSTRUN == true ]]; then

    # check for errors
    if [[ -z "$IDRACIP" ]]; then
      logInfo "Error" "IP not provided"
      exit 1
    elif [[ -z "$IDRACUSER" ]]; then
      logInfo "Error" "USER not provided"
      exit 1
    elif [[ -z "$IDRACPASSWORD" ]]; then
      logInfo "Error" "PASSWORD not provided"
      exit 1
    else
      # set LASTTEMP and FANSPEED on first run
  		LASTTEMP=$TOP_CPU_TEMP
  		FANSPEED=$(($TOP_CPU_TEMP-10))
      FIRSTRUN=false
      logInfo "Start"
      logInfo "ip:${IDRACIP} user:${IDRACUSER} threshold:${TEMPTHRESHOLD} fanmin:${FANSPEEDMIN}% fanmax:${FANSPEEDMAX}% delay:${DELAY}"
    fi
	fi

  # call impitool, get all sensors.
  readarray -t elist < <( ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sdr elist full | sed 1p )
  # "sed 1p" dups first element, so we ignore it below [[ $i != 0 ]]

  # reset arrays
  ARR_FANS=()
  ARR_INLET_TEMP=()
  ARR_EXHAUST_TEMP=()
  ARR_AMPS=()
  ARR_VOLTAGE=()
  ARR_WATTS=()
  ARR_CPU_TEMP=()

  for i in "${!elist[@]}"; do
    if [[ $i != 0 ]] && [[ ${elist[i]} == *"Fan"* ]]; then
      # echo "ARR_FANS:" ${elist[i]}
      IFS='|' read -r -a array <<< $(echo ${elist[i]} | sed 's/ //g' | sed 's/RPM//g')
      ARR_FANS+=("${array[4]}")

    elif [[ $i != 0 ]] && [[ ${elist[i]} == *"Inlet Temp"* ]]; then
      # echo "ARR_INLET_TEMP:" ${elist[i]}
      IFS='|' read -r -a array <<< $(echo ${elist[i]} | sed 's/ //g' | sed 's/degreesC//g')
      ARR_INLET_TEMP+=("${array[4]}")
      STRING_INLET_TEMP=$STRING_INLET_TEMP"InletTemp${i}:"${array[4]}"c "

    elif [[ $i != 0 ]] && [[ ${elist[i]} == *"Exhaust Temp"* ]]; then
      # echo "ARR_EXHAUST_TEMP:" ${elist[i]}
      IFS='|' read -r -a array <<< $(echo ${elist[i]} | sed 's/ //g' | sed 's/degreesC//g')
      ARR_EXHAUST_TEMP+=("${array[4]}")
      STRING_EXHAUST_TEMP=$STRING_EXHAUST_TEMP$"ExhaustTemp${i}:"${array[4]}"c "

    elif [[ $i != 0 ]] && [[ ${elist[i]} == *"Amps"* ]]; then
      # echo "ARR_AMPS:" ${elist[i]}
      IFS='|' read -r -a array <<< $(echo ${elist[i]} | sed 's/ //g' | sed 's/Amps//g')
      ARR_AMPS+=("${array[4]}")
      STRING_AMPS=$STRING_AMPS"Amps${i}:"${array[4]}" "

    elif [[ $i != 0 ]] && [[ ${elist[i]} == *"Volts"* ]]; then
      # echo "ARR_VOLTAGE:" ${elist[i]}
      IFS='|' read -r -a array <<< $(echo ${elist[i]} | sed 's/ //g' | sed 's/Volts//g')
      ARR_VOLTAGE+=("${array[4]}")
      STRING_VOLTS=$STRING_VOLTS"Volts${i}:"${array[4]}" "

    elif [[ $i != 0 ]] && [[ ${elist[i]} == *"Watts"* ]]; then
      # echo "ARR_WATTS:" ${elist[i]}
      IFS='|' read -r -a array <<< $(echo ${elist[i]} | sed 's/ //g' | sed 's/Watts//g')
      ARR_WATTS+=("${array[4]}")
      STRING_WATTS=$STRING_WATTS"Watts${i}:"${array[4]}" "

    elif [[ $i != 0 ]] && [[ ${elist[i]} == *"Temp"* ]] && [[ ${elist[i]} != *"Inlet"* ]] && [[ ${elist[i]} != *"Exhaust"* ]]; then
      # echo "ARR_CPU_TEMP:" ${elist[i]}
      IFS='|' read -r -a array <<< $(echo ${elist[i]} | sed 's/ //g' | sed 's/degreesC//g')
      ARR_CPU_TEMP+=("${array[4]}")

    fi
  done

  # capture top fan speed
  local log_fans
  for i in "${!ARR_FANS[@]}"; do
   if [[ ${ARR_FANS[i]} =~ ^[-+]?[0-9]+\.?[0-9]*$ ]];then
     local x=$((i+1))
     if [[ $x -le ${#ARR_FANS[*]} ]]; then
       if [[ ${ARR_FANS[i]} > ${ARR_FANS[x]} ]]; then
         TOP_FAN_SPEED=${ARR_FANS[i]}
       else
         TOP_FAN_SPEED=${ARR_FANS[x]}
       fi
       log_fans=$log_fans"FAN$x:"${ARR_FANS[i]}"rpm "
     fi
   fi
  done

  # capture inlet temp
  local log_inlet_temp
  for i in "${!ARR_INLET_TEMP[@]}"; do
   if [[ ${ARR_INLET_TEMP[i]} =~ ^[-+]?[0-9]+\.?[0-9]*$ ]];then
     local x=$((i+1))
     if [[ $x -le ${#ARR_INLET_TEMP[*]} ]]; then
       log_inlet_temp=$log_inlet_temp"INLET"$x"TEMP:"${ARR_INLET_TEMP[i]}"c "
     fi
   fi
  done

  # capture exhaust temp
  local log_exhaust_temp
  for i in "${!ARR_EXHAUST_TEMP[@]}"; do
   if [[ ${ARR_EXHAUST_TEMP[i]} =~ ^[-+]?[0-9]+\.?[0-9]*$ ]];then
     local x=$((i+1))
     if [[ $x -le ${#ARR_EXHAUST_TEMP[*]} ]]; then
       log_exhaust_temp=$log_exhaust_temp"EXHAUST"$x"TEMP:"${ARR_EXHAUST_TEMP[i]}"c "
     fi
   fi
  done

  # capture amps
  local log_amps
  for i in "${!ARR_AMPS[@]}"; do
   if [[ ${ARR_AMPS[i]} =~ ^[-+]?[0-9]+\.?[0-9]*$ ]];then
     local x=$((i+1))
     if [[ $x -le ${#ARR_AMPS[*]} ]]; then
       log_amps=$log_amps"CURRENT$x:"${ARR_AMPS[i]}" "
     fi
   fi
  done

  # capture volts
  local log_voltage
  for i in "${!ARR_VOLTAGE[@]}"; do
   if [[ ${ARR_VOLTAGE[i]} =~ ^[-+]?[0-9]+\.?[0-9]*$ ]];then
     local x=$((i+1))
     if [[ $x -le ${#ARR_VOLTAGE[*]} ]]; then
       log_voltage=$log_voltage"VOLTAGE$x:"${ARR_VOLTAGE[i]}"v "
     fi
   fi
  done

  # capture watts
  local log_watts
  for i in "${!ARR_WATTS[@]}"; do
   if [[ ${ARR_WATTS[i]} =~ ^[-+]?[0-9]+\.?[0-9]*$ ]];then
     local x=$((i+1))
     if [[ $x -le ${#ARR_WATTS[*]} ]]; then
       log_watts=$log_watts"WATTS$x:"${ARR_WATTS[i]}" "
     fi
   fi
  done

  # capture cpu temp
  local log_cpu_temp
  for i in "${!ARR_CPU_TEMP[@]}"; do
    if [[ ${ARR_CPU_TEMP[i]} =~ ^[-+]?[0-9]+\.?[0-9]*$ ]];then
      local x=$((i+1))
      if [[ $x -le ${#ARR_CPU_TEMP[*]} ]]; then
        if [[ ${ARR_CPU_TEMP[i]} > ${ARR_CPU_TEMP[x]} ]]; then
          TOP_CPU_TEMP=${ARR_CPU_TEMP[i]}
        else
          TOP_CPU_TEMP=${ARR_CPU_TEMP[x]}
        fi
        log_cpu_temp=$log_cpu_temp" CPU"$x"TEMP:"${ARR_CPU_TEMP[i]}"c "
      fi
    fi
  done

  logInfo "INFO" "${log_fans}  ${log_inlet_temp}  ${log_exhaust_temp}  ${log_amps} ${log_voltage}  ${log_watts}  ${log_cpu_temp}"
}


function dynamicFanControl(){
	FANCONTROL=${1:-on}
	if [[ $FANCONTROL = "on" ]] && [[ $LASTFANCONTROLVALUE != "on" ]]; then
		LASTFANCONTROLVALUE="on"
		logInfo "INFO" "enable dynamic fan control"
		ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x01 0x01
	elif [[ $FANCONTROL = "off" ]] && [[ $LASTFANCONTROLVALUE != "off" ]]; then
		LASTFANCONTROLVALUE="off"
		logInfo "INFO" "disable dynamic fan control"
		ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x01 0x00
	fi
}

function changeFanSpeed(){
	# convert fan speed value from dec to hex
	local HEXVALUE=$(printf "%x" $1)
  # set fan speed %
	ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x02 0xff 0x$HEXVALUE
}

while true
do
	# call ipmitool and return temperature & fanspeed
	getSensors

	# only control fan speed if highest cpu temp is higher then threshold
	if [[ $TOP_CPU_TEMP > $TEMPTHRESHOLD ]]; then
		# disable dynamic fan control
		dynamicFanControl "off"

		# Increase or decrease a fan speed to match cpu temp changes
		if [[ $FANSPEED < $FANSPEEDMAX && $TOP_CPU_TEMP > $LASTTEMP ]]; then
      changeFanSpeed $((FANSPEED+1))
      logInfo "INFO" "speed up fan"

		elif [[ $FANSPEED > $FANSPEEDMIN && $TOP_CPU_TEMP < $LASTTEMP ]]; then
      changeFanSpeed $((FANSPEED-1))
			logInfo "INFO" "slow down fan"

		else
			logInfo "INFO" "idle no change"

		fi
	else
    # reset fan speed value
		FANSPEED=$(($TOP_CPU_TEMP-10))

		# enable dynamic fan control
		dynamicFanControl "on"
    logInfo "INFO" "idle dynamic state"
	fi
	LASTTEMP=$TOP_CPU_TEMP
	sleep $DELAY
done
