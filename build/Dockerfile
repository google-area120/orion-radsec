# Use official alpine release
FROM alpine:latest as build


#Download URLs for the radsecproxy and openssl
ARG RADSECURL=https://github.com/radsecproxy/radsecproxy/releases/download/1.8.1/
ARG RADSECFILENAME=radsecproxy-1.8.1.tar.gz



#Create the Working dir
RUN mkdir /radsecproxy

# Change working dir
WORKDIR /radsecproxy

# Install buildtools
RUN apk update \
 && apk add --no-cache make g++ openssl-dev nettle-dev musl-dev


# Download and build radsecproxy
RUN wget ${RADSECURL}${RADSECFILENAME} \
 && tar xf ${RADSECFILENAME} --strip-components=1 \
 && ./configure --prefix=/root/output --sysconfdir=/etc --with-ssl=/root/output/ \
 && make && make install


# Install packages from which we will extract diagnostic tools
RUN apk update \
 && apk add --no-cache wpa_supplicant freeradius freeradius-utils


# --- --- ---


# Create Radsecproxy container
FROM alpine:latest

# Install tini init system
RUN apk update \
 && apk add --no-cache tini

# Install dependencies for radsecproxy
RUN apk update \
 && apk add --no-cache openssl ca-certificates nettle

# Install dependencies for debugging tools
RUN apk update \
 && apk add --no-cache talloc pcsc-lite-libs dbus-libs freeradius-lib tcpdump stunnel

# Copy radsecproxy from 'build' stage
COPY --from=build /root/output/ /


COPY --from=build /sbin/eapol_test /usr/local/bin/
COPY --from=build /usr/bin/radclient /usr/local/bin/
COPY --from=build /usr/bin/radsniff /usr/local/bin/

COPY healthcheck.sh /

WORKDIR /root

ENTRYPOINT ["/sbin/tini", "--"]

CMD [ "/sbin/radsecproxy","-f","-c","/etc/radsecproxy.conf","-i","/var/run/radsecproxy.pid" ]

HEALTHCHECK --interval=60s --timeout=15s --retries=3 --start-period=5s CMD /healthcheck.sh
