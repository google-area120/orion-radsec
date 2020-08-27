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

#Clean up script
echo "Cleaning all the files/directories installed for the Radsec Proxy deployment"

#if exists remove the certs directory
CERTS_DIR=$HOME/certs/

if [ -d "$CERTS_DIR" ] 
then
    sudo rm -fr $CERTS_DIR
fi
echo "..erased all cert related artifacts( $CERTS_DIR )" 



#if exists remove the radsecproxy directory

RADSECPROXY_DIR=$HOME/radsecproxy/

if [ -d "$RADSECPROXY_DIR" ] 
then
    sudo rm -fr $RADSECPROXY_DIR
fi
echo "..erased git downloads ( $RADSECPROXY_DIR )" 


#Purge the installed packages as part of setup
sudo apt-get purge git unzip tree -y
echo "..purged all installed packages( git, tree and unzip )"

echo "Cleaning done"
