# Orion Radsecproxy docker setup

In order to deploy Orion Wifi, you must either have a wireless controller that
supports native Radsec or deploy a Radsec proxy. Orion Wifi provides the
required certificates (`radsec.zip`) in the Support section of the Admin
console.  Those certificates will be needed in combination with the script
hosted here.

This repository contains scripts used to automate the deployment process 


For more information about Orion Wifi, click [here](https://orion.area120.com). You may also visit the ‘Help & Support’ tab in your [Orion WiFi](https://orionwifi.area120.com/supply/Home) admin console to view the latest Deployment Guide.


1. `git clone https://github.com/google-area120/orion-radsec.git`
2. Download your certificate zipfile from the Orion Supplier console. This file
   will be called `radsec.zip`.
3. ` cd orion-radsec && mv <path to your radsec.zip> .`
4. `unzip -n radsec.zip`
5. If your machine does not have docker, docker-compose, etc, the run
   `setup_scripts/setup.sh`
6. Run the start script `./run.sh`
The result should be something like:

```
~/orion-radsec$ ./run.sh
[sudo] password for <username>:
Sending build context to Docker daemon  248.8kB
Step 1/6 : FROM alpine:latest
---> a24bb4013296
Step 2/6 : RUN apk update && apk upgrade && apk add openssl freeradius
---> Using cache
---> 3c37f495906a
Step 3/6 : COPY --chown=radius:radius radiusd.conf /etc/raddb/radiusd.conf
---> Using cache
---> 3a231b7d6d51
Step 4/6 : COPY --chown=radius:radius cacerts/ /etc/raddb/cacerts
---> Using cache
---> 10605c59c4dd
Step 5/6 : EXPOSE 1812:1812/udp 1812:1813/udp
---> Using cache
---> 31ac1ef62a07
Step 6/6 : CMD ["/usr/sbin/radiusd","-f","-lstdout"]
---> Using cache
---> 20d9386d2dea
Successfully built 20d9386d2dea
Successfully tagged frrsp:latest
0eaf3f3d57fd6a406a898845ca72689f2fe79f6d8009ded5e414433efff6bc59
~/orion-radsec$ sudo docker logs 0eaf
Tue Aug 10 12:58:10 2021 : Info: Starting - reading configuration files ...
Tue Aug 10 12:58:10 2021 : Info: Found debugger attached
Tue Aug 10 12:58:10 2021 : Info: Loaded virtual server <default>
Tue Aug 10 12:58:10 2021 : Info: Loaded virtual server default
Tue Aug 10 12:58:10 2021 : Info: Ready to process requests
```

Your instance should now be running.
