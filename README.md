# ipmitool
iDRAC fan control


Run just the script
```
ipmitool.sh \
	${IDRACIP} \
	${IDRACUSER} \
	${IDRACPASSWORD} \
	${TEMPTHRESHOLD} \
	${FANSPEEDMIN} \
	${FANSPEEDMAX} \
	${DELAY}
```

Build docker image
```
docker build -t "xparr76/ipmitool" .
```

Run docker container
```
docker run -d --name ipmitool \
	-e IDRACIP=<ip> \								# IP of iDRAC controller
	-e IDRACUSER=<user> \						# username for iDRAC
	-e IDRACPASSWORD=<password> \		# password for iDRAC
	-e TEMPTHRESHOLD=40 \						# At or above temperature in Celsius script takes over from system "dynamic fan control"
	-e FANSPEEDMIN=20 \							# Minimum % fan speed desired while "dynamic fan control" is disabled.
	-e FANSPEEDMAX=40 \							# Maximum % fan speed desired while "dynamic fan control" is disabled.
	-e DELAY=5 \										# Interval between ipmitool request
	-v ${PWD}:/logs xparr76/ipmitool:latest
```

Example: Check every 3 seconds, if temp is over 40c, restrict fans speeds to within 20%/40% range.
```
docker run -d --name ipmitool -e IDRACIP=192.168.0.50 -e IDRACUSER=myusername -e IDRACPASSWORD=mypassword -e TEMPTH
RESHOLD=40 -e FANSPEEDMIN=20 -e FANSPEEDMAX=40 -e DELAY=3 -v /logs:/logs xparr76/ipmitool:latest
```
