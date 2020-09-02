#!/bin/bash

# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

sudo apt-get update
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    gnupg


# Install some helper utilities
sudo apt-get -y install tree jq unzip


# Install Docker from the official repo
DISTRO=$(lsb_release -is | tr 'A-Z' 'a-z')

curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | sudo apt-key add -

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/$DISTRO \
   $(lsb_release -cs) \
   stable"

sudo apt-get update
sudo apt-get -y install docker-ce docker-ce-cli containerd.io
# add current user to docker group so there is no need to use sudo when running docker
sudo usermod -aG docker $(whoami)

echo "Docker Installed"
if  ! sudo docker --version;
then
    echo "Failed to install Docker"
    exit 1
fi


if  ! sudo docker info;
then
    echo "Docker Daemon is not Running"
    echo "Starting Docker Daemon"
    sudo systemctl start docker
fi


# Docker doesn't currently restart unhealthy containers, so we need to do this
sudo cp `dirname $0`/CRON.docker-restart-unhealthy-containers /etc/cron.d/docker-restart-unhealthy-containers

echo "Installation Completed"
