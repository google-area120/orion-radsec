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

#
#  Default settings are read from the following file if it exists, otherwise
#  the hardcoded defaults below are used.
#
CONFIG_FILE=$HOME/.radsecproxy_container_rc


#
#  Set to ASK=1 to interactively override the defaults
#
ASK=


#
#  Hardcoded defaults
#
DEFAULT_ZIP_FILE=$HOME/radsec.zip
DEFAULT_RADSEC_DESTINATION_IP=216.239.32.91
DEFAULT_RADSEC_DESTINATION_PORT=2083
DEFAULT_RADIUS_SECRET=
DEFAULT_RADIUS_LOCAL_AUTH_PORT=1812
DEFAULT_RADIUS_LOCAL_ACCT_PORT=1813
DEFAULT_RADSECPROXY_CONFIG_TEMPLATE=$(readlink -f $(dirname $0)/../config/radsecproxy.conf)
DEFAULT_RADSECPROXY_CONTAINER_NAME=radsecproxy
DEFAULT_RADSECPROXY_IMAGE_NAME=terryburton/radsecproxy-alpine:latest

ZIP_KEY_FILENAME=key.pem
ZIP_CRT_FILENAME=cert.pem
ZIP_CA_CERT_DIRNAME=cacerts

EMPTY_ERROR_MESSAGE='is unset or set to empty string.Please set the variable to continue'
PORT_ERROR_MESSAGE='is unset or set to empty. Setting the port to default'
NOT_VALID_PORT_ERROR_MESSAGE=' is not a valid port'


container_exists ()
{
    local container=$1
    if ! sudo docker container inspect "$RADSECPROXY_CONTAINER_NAME" &>/dev/null;
    then
        return 1
    fi
    return 0
}


container_running ()
{
    local container=$1
    local running=""
    if ! container_exists "$1"; then
        return 2
    fi
    running=$(sudo docker container inspect -f '{{.State.Running}}' "$RADSECPROXY_CONTAINER_NAME")
    if [ "$running" != "true" ];
    then
        return 1
    fi
    return 0
}


remove_container ()
{
    local container=$1
    if ! sudo docker rm -f "$1" >/dev/null;
    then
        echo "Failed to remove the container!" >&2
        return 1
    fi
    if container_exists "$1";
    then
        echo "Asked Docker to remove the container but it still exists!" >&2
        return 2
    fi
    return 0
}


validate_ip ()
{
    local ip=$1
    local stat=1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}


validate_port ()
{
    local re='^[0-9]+$';
    local port=$1;
    [[ -n ${port//[0-9]/} ]] && { return 1; }
    [ "$port" -gt 65535 ] && { return 1; }
    [ "$port" -lt 0 ] && { return 1; }
    return 0
}


cleanup ()
{
    if [[ "$TMP_DIR" = "/tmp/radsec."* ]]; then
        rm -rf $TMP_DIR
    fi
}


#======================
#   Main starts here
#======================


#
#  Run the setup.sh script if Docker is not yet running
#
if ! pgrep -u root dockerd &>/dev/null; then
        echo Docker is not yet running, so we try running the setup.sh script
        echo
        echo Running setup
        echo -------------
        echo
        if ! $(dirname $0)/setup.sh; then
            echo Setup script failed. Stopping.
            exit 1
        fi
        echo
        echo Resuming the container build
        echo ----------------------------
fi


#
#  Write a new config file using defaults if it doesn't exist
#
if [ ! -e "$CONFIG_FILE" ]; then
    cat <<EOF >$CONFIG_FILE
DEFAULT_ZIP_FILE=$DEFAULT_ZIP_FILE
DEFAULT_RADSEC_DESTINATION_IP=$DEFAULT_RADSEC_DESTINATION_IP
DEFAULT_RADSEC_DESTINATION_PORT=$DEFAULT_RADSEC_DESTINATION_PORT
DEFAULT_RADIUS_SECRET=$DEFAULT_RADIUS_SECRET
DEFAULT_RADIUS_LOCAL_AUTH_PORT=$DEFAULT_RADIUS_LOCAL_AUTH_PORT
DEFAULT_RADIUS_LOCAL_ACCT_PORT=$DEFAULT_RADIUS_LOCAL_ACCT_PORT
DEFAULT_RADSECPROXY_CONFIG_TEMPLATE=$DEFAULT_RADSECPROXY_CONFIG_TEMPLATE
DEFAULT_RADSECPROXY_CONTAINER_NAME=$DEFAULT_RADSECPROXY_CONTAINER_NAME
DEFAULT_RADSECPROXY_IMAGE_NAME=$DEFAULT_RADSECPROXY_IMAGE_NAME
EOF
fi


#
#  Read the defaults from the config file
#
source $CONFIG_FILE


#
#  Remove the existing container if it is running
#
RADSECPROXY_CONTAINER_NAME="$DEFAULT_RADSECPROXY_CONTAINER_NAME"
if container_exists "$RADSECPROXY_CONTAINER_NAME" &>/dev/null;
then

    echo
    if container_running "$RADSECPROXY_CONTAINER_NAME"; then
        echo "The container \"$RADSECPROXY_CONTAINER_NAME\" is currently running and will be redeployed if you continue!"
    else
        echo "The container \"$RADSECPROXY_CONTAINER_NAME\" exists (but is stopped) and will be redeployed if you continue!"
    fi
    echo

    read -p "Please type \"yes\" to stop and remove the existing container: " flag

    : ${flag:="no"};
    if [[ "$flag" == "yes" ]];
    then
        echo -n "Removing container... "
        if ! remove_container "$RADSECPROXY_CONTAINER_NAME"; then
            echo "failed!"
            exit 1
        fi
        echo "success"
    else
        echo
        echo "Deployment aborted by the user."
        echo
        exit 100
    fi
fi


#
#  Prompt for the location of the zipfile containing the site credentials if
#  not supplied as an argument and not at the default location
#

DEFAULT_ZIP_FILE=${1:-$DEFAULT_ZIP_FILE}
if [ -r "$DEFAULT_ZIP_FILE" -a -z "$ASK" ]; then
    ZIP_FILE="$DEFAULT_ZIP_FILE"
    echo
    echo "Using the following ZIP file for site credentials: $ZIP_FILE"
else
    while true
        do
            echo
                read -p "Please enter the location of the ZIP file containing the site credentials [default=$DEFAULT_ZIP_FILE]: " ZIP_FILE
            : ${ZIP_FILE:=$DEFAULT_ZIP_FILE}
            if ! [ -r $ZIP_FILE ];
            then
               echo "Error: $ZIP_FILE could not be read"
            else
                break
            fi
        done
fi
ZIP_FILE=$(readlink -f "$ZIP_FILE")


#
# Unpack the zipfile and perform a basic check on the contents
#

echo -n "Unpacking the credential ZIP file... "
TMP_DIR=$(mktemp -d /tmp/radsec.XXXXXXXX)
if ! unzip -q -d "$TMP_DIR" "$ZIP_FILE"; then
    echo "unzip failed" >&2
    exit 1
fi

DEFAULT_RADSEC_CRT_FILE="$TMP_DIR/$ZIP_CRT_FILENAME"
DEFAULT_RADSEC_KEY_FILE="$TMP_DIR/$ZIP_KEY_FILENAME"
DEFAULT_RADSEC_CA_CERT_PATH="$TMP_DIR/$ZIP_CA_CERT_DIRNAME"

if ! [ -f "$DEFAULT_RADSEC_CRT_FILE" ];     then echo "ZIP file does not contain $ZIP_CRT_FILENAME file" 2>&1; exit; fi
if ! [ -f "$DEFAULT_RADSEC_KEY_FILE" ];     then echo "ZIP file does not contain $ZIP_KEY_FILENAME file" 2>&1; exit; fi
if ! [ -d "$DEFAULT_RADSEC_CA_CERT_PATH" ]; then echo "ZIP file does not contain $ZIP_CA_CERT_DIRNAME directory" 2>&1; exit; fi

chmod 660 $DEFAULT_RADSEC_KEY_FILE

echo "successfully unzipped to: $TMP_DIR"
echo

#**********************************************************************************
#                               DEFAULT CONFIG LIST
#  If ASK=1 then confirm with user with Default config Read from the prompt in
#  case of change in the values
#
#  In case of file paths confirm if the file exists
#  uses the default value if the user enters nothing (empty string)
#**********************************************************************************


#
# We always prompt for the RADIUS secret and generate randomly if it is blank
#

read -p "Please enter the RADIUS secret [default=${DEFAULT_RADIUS_SECRET:-<RANDOMLY_GENERATED>}]: " RADIUS_SECRET
if [ -z "$RADIUS_SECRET" -a -z "$DEFAULT_RADIUS_SECRET" ]; then
    RADIUS_SECRET=$(mktemp -u XXXXXXXXXXXXXXXX)
fi
: ${RADIUS_SECRET:=$DEFAULT_RADIUS_SECRET}


if [ -n "$ASK" ]; then
while true
    do
        read -p "RADIUS_LOCAL_AUTH_PORT [default=$DEFAULT_RADIUS_LOCAL_AUTH_PORT] :" RADIUS_LOCAL_AUTH_PORT
        : ${RADIUS_LOCAL_AUTH_PORT:=$DEFAULT_RADIUS_LOCAL_AUTH_PORT}
        if ! validate_port "$RADIUS_LOCAL_AUTH_PORT";
        then
            echo "Error: Invalid Port $RADIUS_LOCAL_AUTH_PORT"
        else
            break
        fi
    done
else
    RADIUS_LOCAL_AUTH_PORT="$DEFAULT_RADIUS_LOCAL_AUTH_PORT"
fi


if [ -n "$ASK" ]; then
while true
    do
        read -p "RADIUS_LOCAL_ACCT_PORT [default=$DEFAULT_RADIUS_LOCAL_ACCT_PORT]: " RADIUS_LOCAL_ACCT_PORT
        : ${RADIUS_LOCAL_ACCT_PORT:=$DEFAULT_RADIUS_LOCAL_ACCT_PORT}
        if ! validate_port "$RADIUS_LOCAL_ACCT_PORT";
        then
            echo "Error: Invalid Port: $RADIUS_LOCAL_ACCT_PORT"
        else
            break
        fi
    done
else
    RADIUS_LOCAL_ACCT_PORT="$DEFAULT_RADIUS_LOCAL_ACCT_PORT"
fi



if [ -n "$ASK" ]; then
while true
    do
        read -p "RADSEC_DESTINATION_IP [default=$DEFAULT_RADSEC_DESTINATION_IP]: " RADSEC_DESTINATION_IP
        : ${RADSEC_DESTINATION_IP:=$DEFAULT_RADSEC_DESTINATION_IP}
        if ! validate_ip $RADSEC_DESTINATION_IP;
        then
            echo "Error: Invalid IP Address: $RADSEC_DESTINATION_IP"
        else
            break
        fi
    done
else
    RADSEC_DESTINATION_IP="$DEFAULT_RADSEC_DESTINATION_IP"
fi


if [ -n "$ASK" ]; then
while true
    do
        read -p "RADSEC_DESTINATION_PORT [default=$DEFAULT_RADSEC_DESTINATION_PORT]: " RADSEC_DESTINATION_PORT
        : ${RADSEC_DESTINATION_PORT:=$DEFAULT_RADSEC_DESTINATION_PORT}
        if ! validate_port "$RADSEC_DESTINATION_PORT";
        then
            echo "Error: Invalid Port: $RADSEC_DESTINATION_PORT"
        else
            break
        fi
    done
else
    RADSEC_DESTINATION_PORT="$DEFAULT_RADSEC_DESTINATION_PORT"
fi


if [ -n "$ASK" ]; then
while true
    do
        read -p "RADSEC_CA_CERT_PATH directory path [default=$DEFAULT_RADSEC_CA_CERT_PATH]: " CA_CERT_PATH
        : ${RADSEC_CA_CERT_PATH:=$DEFAULT_RADSEC_CA_CERT_PATH}
        if [ ! -d "$RADSEC_CA_CERT_PATH" ];
        then
            echo "Error: $RADSEC_CA_CERT_PATH does not exist. Please enter valid directory path"
        else
            break
        fi
    done
else
    RADSEC_CA_CERT_PATH="$DEFAULT_RADSEC_CA_CERT_PATH"
fi


if [ -n "$ASK" ]; then
while true
    do
        read -p "RADSEC_KEY_FILE file path [default=$DEFAULT_RADSEC_KEY_FILE]: " RADSEC_KEY_FILE
        : ${RADSEC_KEY_FILE:=$DEFAULT_RADSEC_KEY_FILE}
        if [ ! -f "$RADSEC_KEY_FILE" ];
        then
            echo "Error: $RADSEC_KEY_FILE does not exist. Please enter valid file path"
        else
            break
        fi
    done
else
    RADSEC_KEY_FILE="$DEFAULT_RADSEC_KEY_FILE"
fi


if [ -n "$ASK" ]; then
while true
    do
        read -p "RADSEC_CRT_FILE file path [default=$DEFAULT_RADSEC_CRT_FILE]: " RADSEC_CRT_FILE
        : ${RADSEC_CRT_FILE:=$DEFAULT_RADSEC_CRT_FILE}
        if [ ! -f "$RADSEC_CRT_FILE" ];
        then
            echo "Error: $RADSEC_CRT_FILE does not exist. Please enter valid file path"
        else
            break
        fi
    done
else
    RADSEC_CRT_FILE="$DEFAULT_RADSEC_CRT_FILE"
fi


if [ -n "$ASK" ]; then
while true
    do
        read -p "RADSECPROXY_CONFIG_TEMPLATE [default=$DEFAULT_RADSECPROXY_CONFIG_TEMPLATE]: " RADSECPROXY_CONFIG_TEMPLATE
        : ${RADSECPROXY_CONFIG_TEMPLATE:=$DEFAULT_RADSECPROXY_CONFIG_TEMPLATE}
        if [ ! -f "$RADSECPROXY_CONFIG_TEMPLATE" ];
        then
            echo "Error: $RADSECPROXY_CONFIG_TEMPLATE does not exist. Please enter valid file path to the template"
        else
            break
        fi
    done
else
    RADSECPROXY_CONFIG_TEMPLATE="$DEFAULT_RADSECPROXY_CONFIG_TEMPLATE"
fi


if [ -n "$ASK" ]; then
read -p "RADSECPROXY_CONTAINER_NAME [default=$DEFAULT_RADSECPROXY_CONTAINER_NAME]: " RADSECPROXY_CONTAINER_NAME
: ${RADSECPROXY_CONTAINER_NAME:=$DEFAULT_RADSECPROXY_CONTAINER_NAME}
else
    RADSECPROXY_CONTAINER_NAME="$DEFAULT_RADSECPROXY_CONTAINER_NAME"
fi


if [ -n "$ASK" ]; then
read -p "RADSECPROXY_IMAGE_NAME [default=$DEFAULT_RADSECPROXY_IMAGE_NAME]: " RADSECPROXY_IMAGE_NAME
: ${RADSECPROXY_IMAGE_NAME:=$DEFAULT_RADSECPROXY_IMAGE_NAME}
else
    RADSECPROXY_IMAGE_NAME="$DEFAULT_RADSECPROXY_IMAGE_NAME"
fi


#**********************************************************************************
#               Display the configuration
#**********************************************************************************

cat <<EOF

Configuration:

RADIUS_SECRET=$RADIUS_SECRET
RADIUS_LOCAL_AUTH_PORT=$RADIUS_LOCAL_AUTH_PORT
RADIUS_LOCAL_ACCT_PORT=$RADIUS_LOCAL_ACCT_PORT
RADSEC_DESTINATION_IP=$RADSEC_DESTINATION_IP
RADSEC_DESTINATION_PORT=$RADSEC_DESTINATION_PORT
RADSEC_CA_CERT_PATH=$RADSEC_CA_CERT_PATH
RADSEC_KEY_FILE=$RADSEC_KEY_FILE
RADSEC_CRT_FILE=$RADSEC_CRT_FILE
RADSECPROXY_CONFIG_TEMPLATE=$RADSECPROXY_CONFIG_TEMPLATE
RADSECPROXY_CONTAINER_NAME=$RADSECPROXY_CONTAINER_NAME
RADSECPROXY_IMAGE_NAME=$RADSECPROXY_IMAGE_NAME

EOF


#**********************************************************************************
#               Build radsecproxy.conf from its template
#**********************************************************************************

echo "Creating radsecproxy.conf from template: $RADSECPROXY_CONFIG_TEMPLATE"

RADSECPROXY_CONFIG=(
    RADSEC_DESTINATION_IP
    RADSEC_DESTINATION_PORT
    RADIUS_SECRET
)

RADSECPROXY_CONFIG_VALUES=(
    $RADSEC_DESTINATION_IP
    $RADSEC_DESTINATION_PORT
    $RADIUS_SECRET
)

RADSECPROXY_CONFIG_FILE=$TMP_DIR/$(basename $RADSECPROXY_CONFIG_TEMPLATE)

if ! [ -r "$RADSECPROXY_CONFIG_TEMPLATE" ]; then
    echo "Failed to read the radsecproxy.conf template"
    exit 1
fi

cp -f $RADSECPROXY_CONFIG_TEMPLATE $RADSECPROXY_CONFIG_FILE
for index in ${!RADSECPROXY_CONFIG[*]}
    do
        echo -n "Updating ${RADSECPROXY_CONFIG[$index]} in the config file... "
        perl -pi -e 's/'${RADSECPROXY_CONFIG[$index]}'/'${RADSECPROXY_CONFIG_VALUES[$index]}'/g' \
            $RADSECPROXY_CONFIG_FILE
        echo "done"
    done


#**********************************************************************************
#               Validate if the Docker images Exists
#**********************************************************************************

#
#  Remote image names contain slash characters, otherwise we assume that the
#  image is local
#

if [[ "$RADSECPROXY_IMAGE_NAME" = *"/"* ]]
then
    echo
    echo "Fetching the remote image for the container: "
    if ! sudo docker pull "$RADSECPROXY_IMAGE_NAME";
    then
        echo "Failed to pull the Docker image"
        exit 1
    fi
else
    if  ! sudo docker image inspect "$RADSECPROXY_IMAGE_NAME" >/dev/null 2>/dev/null;
    then
        echo "The Docker image was not found locally: $RADSECPROXY_IMAGE_NAME"
        exit 1
    fi
fi


#**********************************************************************************
#                   Build the RadsecProxy Container
#**********************************************************************************

#
#  Create the container and allow it to consume up to 50GB of disk for logs
#

echo
echo -n "Creating the container... "

if ! sudo docker create \
        -p $RADIUS_LOCAL_AUTH_PORT:1812/udp -p $RADIUS_LOCAL_ACCT_PORT:1813/udp \
        --name "$RADSECPROXY_CONTAINER_NAME" \
        --restart always \
        --log-opt max-size=500m --log-opt max-file=100 \
        "$RADSECPROXY_IMAGE_NAME";
then
    echo "Failed to create container"
    exit 1
fi

#
#  Modify the container to include credentials and the filled configuation template
#

echo
echo "Copying credentials and configuration into the container"

List=(
    $RADSEC_KEY_FILE
    $RADSEC_CRT_FILE
    $RADSEC_CA_CERT_PATH
    $RADSECPROXY_CONFIG_FILE
)

LOCATION_MAPPING=(
    /etc/ssl/certs/
    /etc/ssl/certs/
    /etc/ssl/certs/
    /etc/
)

for index in ${!List[*]};
do
    echo -n "Copying: ${List[$index]}... "
    if ! tar --owner=0 --group=0 -c -f - -C $(dirname ${List[$index]}) $(basename ${List[$index]}) | \
        sudo docker cp - $RADSECPROXY_CONTAINER_NAME:${LOCATION_MAPPING[$index]};
    then
        echo "Failed to copy file ${List[$index]}"
        cleanup
        remove_container $RADSECPROXY_CONTAINER_NAME
        exit 1
    fi
    echo "done"
done


#
#  Start the Container
#
echo
echo -n "Starting the container: "
if  ! sudo docker start $RADSECPROXY_CONTAINER_NAME;
then
    echo "Failed to start container"
    cleanup
    remove_container $RADSECPROXY_CONTAINER_NAME
    exit 1
fi


#
#  Wait 5 secs for the container to load and show the startup logs
#
sleep 5
echo
echo "Output from radsecproxy running within the container:"
echo
sudo docker logs $RADSECPROXY_CONTAINER_NAME
echo


# Write the configuration entries to a file to supply defaults for a prompted
# install on the next occasion

    cat <<EOF >$CONFIG_FILE
DEFAULT_ZIP_FILE=$ZIP_FILE
DEFAULT_RADSECPROXY_CONFIG_TEMPLATE=$RADSECPROXY_CONFIG_TEMPLATE
DEFAULT_RADSEC_DESTINATION_IP=$RADSEC_DESTINATION_IP
DEFAULT_RADSEC_DESTINATION_PORT=$RADSEC_DESTINATION_PORT
DEFAULT_RADIUS_SECRET=$RADIUS_SECRET
DEFAULT_RADIUS_LOCAL_AUTH_PORT=$RADIUS_LOCAL_AUTH_PORT
DEFAULT_RADIUS_LOCAL_ACCT_PORT=$RADIUS_LOCAL_ACCT_PORT
DEFAULT_RADSECPROXY_CONTAINER_NAME=$RADSECPROXY_CONTAINER_NAME
DEFAULT_RADSECPROXY_IMAGE_NAME=$RADSECPROXY_IMAGE_NAME
EOF


cleanup


cat <<EOF
****************************************************************************

  The RADIUS secret is as follows:

      $RADIUS_SECRET

  Carefully ensure that your NASs are configured with this exact secret.

****************************************************************************

EOF

echo "Finished."
