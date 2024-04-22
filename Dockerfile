FROM alpine:latest
LABEL org.opencontainers.image.source="https://github.com/google-area120/orion-radsec"
LABEL org.opencontainers.image.description="Orion Wifi Customized Docker image for Radsec RADIUS Proxy"
LABEL org.opencontainers.image.authors="google-area120"
RUN apk update && apk upgrade && apk add -q --no-cache bash openssl openssl-dev freeradius freeradius-eap freeradius-lib freeradius-radclient freeradius-pam freeradius-utils freeradius-checkrad tzdata && rm -rf /tmp/* /var/cache/apk/*
COPY --chown=radius:radius radiusd.conf /etc/raddb/radiusd.conf
COPY --chown=radius:radius cacerts/ /etc/raddb/cacerts
EXPOSE 1812/udp 1813/udp
CMD /bin/sh -c "while true; do /usr/sbin/radiusd -f -lstdout; sleep 1; done"
