# Orion Radsecproxy docker setup

For more information about Orion Wifi, click [here](https://orion.google) or visit the [Orion Wifi Help Center](https://support.google.com/orion-wifi).


In order to deploy Orion Wifi, you must either have a wireless controller that
supports native Radsec or deploy a Radsec proxy. Orion Wifi provides the
required certificates (`radsec.zip`) in the Support section of the Admin
console.  Those certificates will be needed in combination with the script
hosted here.



1. `git clone https://github.com/google-area120/orion-radsec.git`
1. Download your certificate bundle:
   * Open [Orion Supply](https://orion.google/supply/Home)
   * Click RadSec Certificates
   * Click Download Orion Certificates > Generate Client Certificate Bundle
1. Your certificate bundle file will download.  This file will be called `radsec.zip`.
1. `cd orion-radsec && mv <path to your radsec.zip> .`
1. `unzip -n radsec.zip`
1. If your machine does not have docker, docker-compose, etc, then run
   `setup_scripts/setup.sh`
1. Run the start script `./run.sh`
The result should be something like:

```
~/orion-radsec$ ./run.sh 
[+] Building 0.6s (10/10) FINISHED
...                            
Wed Jan 29 00:57:59 2025 : Info: Loaded virtual server <default>
Wed Jan 29 00:57:59 2025 : Info: Loaded virtual server default
Wed Jan 29 00:57:59 2025 : Info: Ready to process requests
```

Your instance should now be running.
