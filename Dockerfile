FROM debian:latest
RUN apt update && apt -y upgrade && apt -y install openssl freeradius 
COPY --chown=freerad:freerad radiusd.conf /etc/freeradius/3.0/radiusd.conf
COPY --chown=freerad:freerad clients.conf /etc/freeradius/3.0/clients.conf
COPY --chown=freerad:freerad cacerts/ /etc/freeradius/3.0/cacerts
EXPOSE 1812:1812/udp 1812:1813/udp 
CMD ["/usr/sbin/freeradius","-f","-lstdout"]
