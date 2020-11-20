FROM alpine:latest

LABEL maintainer="xparr76" \
	  name="ipmitool" \
	  version="1.0"

ENV IDRACIP=${IDRACIP}
ENV IDRACUSER=${IDRACUSER}
ENV IDRACPASSWORD=${IDRACPASSWORD}
ENV TEMPTHRESHOLD=${TEMPTHRESHOLD}
ENV FANSPEEDMIN=${FANSPEEDMIN}
ENV FANSPEEDMAX=${FANSPEEDMAX}
ENV DELAY=${DELAY}

RUN apk update && apk upgrade && apk add --update \
	ipmitool \
	bash

VOLUME /logs

COPY ipmitool.sh ipmitool.sh

RUN chmod +x /ipmitool.sh

CMD /ipmitool.sh \
	${IDRACIP} \
	${IDRACUSER} \
	${IDRACPASSWORD} \
	${TEMPTHRESHOLD} \
	${FANSPEEDMIN} \
	${FANSPEEDMAX} \
	${DELAY} || : && bash && tail -f /dev/null