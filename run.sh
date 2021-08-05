#!/bin/bash

pwd=`pwd`

docker run -it  \
    -v $pwd/cert.pem:/etc/raddb/cert.pem \
    -v $pwd/key.pem:/etc/raddb/key.pem \
    frrsp

