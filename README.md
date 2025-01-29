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
[+] Building 0.6s (10/10) FINISHED
...                            
Wed Jan 29 00:57:59 2025 : Info: Debug state unknown (cap_sys_ptrace capability not set)
Wed Jan 29 00:57:59 2025 : Info: systemd watchdog is disabled
Wed Jan 29 00:57:59 2025 : Info: Loaded virtual server <default>
Wed Jan 29 00:57:59 2025 : Info: Loaded virtual server default
Wed Jan 29 00:57:59 2025 : Info: Ready to process requests
```

Your instance should now be running.
