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
6. Run `./build.sh` to build the radsecproxy container.
7. Run the start script `./run.sh`
The result should be:

```
~/orion-radsec$ ./run.sh
0eaf3f3d57fd6a406a898845ca72689f2fe79f6d8009ded5e414433efff6bc59
~/orion-radsec$ sudo docker logs 0eaf
Tue Aug 10 12:58:10 2021 : Info: Starting - reading configuration files ...
Tue Aug 10 12:58:10 2021 : Info: Found debugger attached
Tue Aug 10 12:58:10 2021 : Info: Loaded virtual server <default>
Tue Aug 10 12:58:10 2021 : Info: Loaded virtual server default
Tue Aug 10 12:58:10 2021 : Info: Ready to process requests
```

Your instance should now be running.
