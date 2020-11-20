# ipmitool
idrac fan control



Run just the scrypt
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
	-e IDRACIP=<ip> \
	-e IDRACUSER=<user> \
	-e IDRACPASSWORD=<password> \
	-e TEMPTHRESHOLD=40 \
	-e FANSPEEDMIN=10 \
	-e FANSPEEDMAX=90 \
	-e DELAY=5 \
	-v ${PWD}:/logs xparr76/ipmitool:latest
```
