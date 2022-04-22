FROM alpine:latest
RUN apk update && apk upgrade && apk add openssl freeradius 
COPY --chown=radius:radius radiusd.conf /etc/raddb/radiusd.conf
COPY --chown=radius:radius cacerts/ /etc/raddb/cacerts
COPY --chown=radius:radius key.pem /etc/raddb/key.pem
COPY --chown=radius:radius cert.pem /etc/raddb/cert.pem
EXPOSE 1812:1812/udp 1812:1813/udp 
CMD ["/usr/sbin/radiusd","-f","-lstdout"]
