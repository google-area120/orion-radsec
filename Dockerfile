FROM alpine:latest
RUN apk update && apk upgrade && apk add openssl nettle
RUN apk --no-cache --virtual build-dep add g++ gcc openssl-dev make nettle-dev curl
RUN curl -Lo radsecproxy-1.9.0.tar.gz  https://github.com/radsecproxy/radsecproxy/releases/download/1.9.0/radsecproxy-1.9.0.tar.gz && \
  tar xvf radsecproxy-1.9.0.tar.gz && \
  rm radsecproxy-1.9.0.tar.gz &&\
  cd radsecproxy-1.9.0 && \
  ./configure --prefix=/ && \
  make && \
  make check && \
  make install && \
  touch /var/log/radsecproxy.log && \
  apk del build-dep && \
  rm -rf /radsecproxy-1.9.0
EXPOSE 1812:1812/udp 1812:1813/udp 
ENTRYPOINT ["/sbin/radsecproxy","-f","-d","3"]
