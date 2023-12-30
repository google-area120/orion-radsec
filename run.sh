#!/bin/bash

IMAGE_NAME="frrsp"
CONTAINER_NAME="radsecproxy"
CERT_PATH=$(pwd)/cert.pem
KEY_PATH=$(pwd)/key.pem

# Stop and remove the existing container (if it exists)
sudo docker stop $CONTAINER_NAME
sudo docker rm $CONTAINER_NAME

# Remove the existing image (if it exists)
sudo docker rmi $IMAGE_NAME

# Build the new image
sudo docker build -t $IMAGE_NAME .

# Run the new container
sudo docker run  \
    -d --restart=unless-stopped \
    --network host \
    -p 1812-1813:1812-1813/udp \
    -v $CERT_PATH:/etc/raddb/cert.pem \
    -v $KEY_PATH:/etc/raddb/key.pem \
    --name $CONTAINER_NAME \
    $IMAGE_NAME
