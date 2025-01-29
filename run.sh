#!/bin/bash

pwd=`pwd`

sudo docker build -t frrsp .

sudo docker run  \
    -d --restart=unless-stopped \
    -p 1812-1813:1812-1813/udp \
    -v $pwd/cert.pem:/etc/freeradius/3.0/cert.pem \
    -v $pwd/key.pem:/etc/freeradius/3.0/key.pem \
    frrsp

