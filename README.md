# ipmitool
idrac fan control



Start Script
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

Start scrypt in docker
```
docker build -t "xparr76/ipmitool" .
```
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
