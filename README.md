# Orion Radsecproxy docker setup

In order to deploy Orion Wifi, you must either have a wireless controller that
supports native Radsec or deploy a Radsec proxy. Orion Wifi provides the
required certificates (`radsec.zip`) in the Support section of the Admin
console.  Those certificates will be needed in combination with the script
hosted here.

This repository contains scripts used to automate the deployment process. It
will build and run a docker container to encapsulate radsecproxy along with the
required configuration files and certificates from your Orion WiFi Admin
Console.

For more information about Orion Wifi, click [here](https://orion.area120.com). You may also visit the ‘Help & Support’ tab in your [Orion WiFi](https://orionwifi.area120.com) admin console to view the latest Deployment Guide.
