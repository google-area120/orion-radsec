FROM alpine:latest
RUN apk update && apk upgrade && apk add openssl freeradius 
COPY --chown=radius:radius radiusd.conf /etc/raddb/radiusd.conf
COPY --chown=radius:radius cacerts/ /etc/raddb/cacerts
EXPOSE 1812:1812/udp 1812:1813/udp 
CMD ["/usr/sbin/radiusd","-f","-lstdout"]
