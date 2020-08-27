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

#Default RadsecProxy Configuration
DEFAULT_RADSEC_KEY_FILE=$HOME/certs/key.pem
DEFAULT_RADSEC_CRT_FILE=$HOME/certs/cert.pem
DEFAULT_CA_CERT_FILE=$HOME/certs/cacert.pem
DEFAULT_CA_CERT_PATH=$HOME/certs/cacerts
DEFAULT_RADSEC_CONFIG_FILE=$HOME/radsecproxy/config/radsecproxy.conf

DEFAULT_SECRET=radsec
DEFAULT_MY_TICKS_KEY=radsec
DEFAULT_RADIUS_DESTINATION=216.239.32.91
DEFAULT_RADIUS_DESTINATION_PORT=2083


#Container Config
DEFAULT_RADSECPROXY_SERVER_NAME=myRadSecProxy
DEFAULT_AUTH_PORT=1812
DEFAULT_ACCOUNTING_PORT=1813

#Default Docker Image
DEFAULT_IMAGE_NAME=cloudteamrahi48303/radsecproxy-alpine:latest


#Error Messages
EMPTY_ERROR_MESSAGE='is unset or set to empty string.Please set the variable to continue'
PORT_ERROR_MESSAGE='is unset or set to empty. Setting the port to default'
NOT_VALID_PORT_ERROR_MESSAGE=' is not a valid port'



#**********************************************************************************
#               Validate Running Containers
#**********************************************************************************


containers_running=$(docker ps --format {{.Names}})
if [ ! -z "$containers_running" ];
then
    #echo "Please press enter to delete the running containers $containers_running (yes/no)"
    read -p "Please press enter to delete the running containers $containers_running (yes/no)" flag 
    : ${flag:="yes"};
    if [[ "$flag" == "yes" ]];
    then 
        echo "...deleting containers $containers_running"
        sudo docker rm -f $containers_running 
    else 
        echo "Aborting Deployment!!"
        exit 1
    fi
fi


echo "Please press Enter to accept the default value or type in the override value and press Enter"
#**********************************************************************************
#               Radsecproxy Config Prompt for User
#**********************************************************************************

valid_ip()
{
    local  ip=$1
    local  stat=1
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




#**********************************************************************************
#                   AUTH_PORT & ACCOUNTING_PORT Validation
#  If the AUTH_PORT & ACCOUNTING_PORT are unset or empty set the default ports
#  Validate if the port ranges are between  ephemeral port range 0 to 65535
#**********************************************************************************


validate_port() { 
    local re='^[0-9]+$';
    local port_name=$1;
    local port=$2;
    #echo $port_name $port

    #Check if the port is numeric

    [[ -n ${port//[0-9]/} ]] && { return 1; }

    #validate if the given port is in valid range
    [ "$port" -gt 65535 ] && { return 1; }
    [ "$port" -lt 0 ] && {  return 1; }

    return 0
}




#Radsecproxy Config
RADSECPROXY_CONFIG=(
    RADIUS_DESTINATION_PORT
    RADIUS_DESTINATION
    MY_TICKS_KEY
    SECRET
)



#RADIUS_DESTINATION IP validation
while true
    do
        read -p "RADIUS_DESTINATION [default=$DEFAULT_RADIUS_DESTINATION] :" RADIUS_DESTINATION
        : ${RADIUS_DESTINATION:=$DEFAULT_RADIUS_DESTINATION}
        if ! valid_ip $RADIUS_DESTINATION; 
        then
            echo "Error: $RADIUS_DESTINATION Invalid IP Address"
        else
            break
        fi
    done



#RADIUS_DESTINATION_PORT  validation
while true
    do
        read -p "RADIUS_DESTINATION_PORT [default=$DEFAULT_RADIUS_DESTINATION_PORT] :" RADIUS_DESTINATION_PORT
        : ${RADIUS_DESTINATION_PORT:=$DEFAULT_RADIUS_DESTINATION_PORT}
        if ! $(validate_port "RADIUS_DESTINATION_PORT" $RADIUS_DESTINATION_PORT); 
        then
            echo "Error: $RADIUS_DESTINATION_PORT Invalid Port"
        else
            break
        fi
    done


read -p "MY_TICKS_KEY [default=$DEFAULT_MY_TICKS_KEY] :" MY_TICKS_KEY
: ${MY_TICKS_KEY:=$DEFAULT_MY_TICKS_KEY}


read -p "SECRET [default=$DEFAULT_SECRET] :" SECRET
: ${SECRET:=$DEFAULT_SECRET}



RADSECPROXY_CONFIG_VALUES=(
    $RADIUS_DESTINATION_PORT
    $RADIUS_DESTINATION
    $MY_TICKS_KEY
    $SECRET
)


#RADSEC_CONFIG_FILE file path
while true
    do
        read -p "RADSEC_CONFIG_FILE file path [default=$DEFAULT_RADSEC_CONFIG_FILE] :" RADSEC_CONFIG_FILE
        : ${RADSEC_CONFIG_FILE:=$DEFAULT_RADSEC_CONFIG_FILE}
        if [ ! -f "$RADSEC_CONFIG_FILE" ]; 
        then
            echo "Error: $RADSEC_CONFIG_FILE does not exist. Please enter valid file path"
        else
            break
        fi
    done



#**********************************************************************************
#                               DEFAULT CONFIG LIST 
#  Confirm with user with Default config Read from the prompt in case of change 
#  in the values
#  
#  In case of file paths confirm if the file exists
#  uses the default value if the user enters nothing (empty string)
#**********************************************************************************



# #CA_CERT_FILE file path
# while true
#     do
#         read -p "CA_CERT_FILE file path [default=$DEFAULT_CA_CERT_FILE] :" CA_CERT_FILE
#         : ${CA_CERT_FILE:=$DEFAULT_CA_CERT_FILE}
#         echo $CA_CERT_FILE
#         if [ ! -f "$CA_CERT_FILE" ]; 
#         then
#             echo "Error: $CA_CERT_FILE does not exist. Please enter valid file path"
#         else
#             break
#         fi
#     done


#CA_CERT_FILE directory path path
while true
    do
        read -p "CA_CERT_PATH directory path [default=$DEFAULT_CA_CERT_PATH] :" CA_CERT_PATH
        : ${CA_CERT_PATH:=$DEFAULT_CA_CERT_PATH}
        echo $CA_CERT_PATH
        if [ ! -d "$CA_CERT_PATH" ]; 
        then
            echo "Error: $CA_CERT_PATH does not exist. Please enter valid directory path"
        else
            break
        fi
    done



#RADSEC_KEY_FILE file path
while true
    do
        read -p "RADSEC_KEY_FILE file path [default=$DEFAULT_RADSEC_KEY_FILE] :" RADSEC_KEY_FILE
        : ${RADSEC_KEY_FILE:=$DEFAULT_RADSEC_KEY_FILE}
        if [ ! -f "$RADSEC_KEY_FILE" ]; 
        then
            echo "Error: $RADSEC_KEY_FILE does not exist. Please enter valid file path"
        else
            break
        fi
    done


#RADSEC_CRT_FILE file path
while true
    do
        read -p "RADSEC_CRT_FILE file path [default=$DEFAULT_RADSEC_CRT_FILE] :" RADSEC_CRT_FILE
        : ${RADSEC_CRT_FILE:=$DEFAULT_RADSEC_CRT_FILE}
        if [ ! -f "$RADSEC_CRT_FILE" ]; 
        then
            echo "Error: $RADSEC_CRT_FILE does not exist. Please enter valid file path"
        else
            break
        fi
    done


#**********************************************************************************
#               Update Radsecproxy Config
#**********************************************************************************

# If the supplied template file is under git version control then restore it
git ls-files --error-unmatch $RADSEC_CONFIG_FILE && git checkout $RADSEC_CONFIG_FILE

for index in ${!RADSECPROXY_CONFIG[*]}
    do
        echo "...updating ${RADSECPROXY_CONFIG[$index]} in the config file"
        sudo perl -pi -e 's/'${RADSECPROXY_CONFIG[$index]}'/'${RADSECPROXY_CONFIG_VALUES[$index]}'/g' \
        $RADSEC_CONFIG_FILE
    done




#Docker Container Config
read -p "Container name [default=$DEFAULT_RADSECPROXY_SERVER_NAME] :" RADSECPROXY_SERVER_NAME
: ${RADSECPROXY_SERVER_NAME:=$DEFAULT_RADSECPROXY_SERVER_NAME}





#ACCOUNTING_PORT file path
while true
    do
        read -p "AUTH_PORT [default=$DEFAULT_AUTH_PORT] :" AUTH_PORT
        : ${AUTH_PORT:=$DEFAULT_AUTH_PORT}
        if ! $(validate_port "ACCOUNTING_PORT" $AUTH_PORT);
        then
            echo "Error: $AUTH_PORT Invalid Port"
        else
            break
        fi
    done


#ACCOUNTING_PORT file path
while true
    do
        read -p "ACCOUNTING_PORT [default=$DEFAULT_ACCOUNTING_PORT] :" ACCOUNTING_PORT
        : ${ACCOUNTING_PORT:=$DEFAULT_ACCOUNTING_PORT}
        if ! $(validate_port "ACCOUNTING_PORT" $ACCOUNTING_PORT); 
        then
            echo "Error: $ACCOUNTING_PORT Invalid Port"
        else
            break
        fi
    done




#Docker Container Image Name
read -p "Docker Container Image name [default=$DEFAULT_IMAGE_NAME] :" IMAGE_NAME
: ${IMAGE_NAME:=$DEFAULT_IMAGE_NAME}






# #**********************************************************************************
# #               Validate if the Docker images Exists
# #**********************************************************************************

#Remote image names contain slash characters, otherwise the image is local
if [[ "$IMAGE_NAME" = *"/"* ]]
then
    if  ! sudo docker pull $IMAGE_NAME;
    then
        echo "Failed to pull the Docker image"
        exit 1
    fi
else
    if  ! sudo docker image inspect $IMAGE_NAME >/dev/null 2>/dev/null;
    then
        echo "The Docker image was not found locally"
        exit 1
    fi
fi


# #**********************************************************************************
# #                   Build the RadsecProxy Container
# #**********************************************************************************

#Remove the Container on Failure
remove_container(){
    if sudo docker rm -f $RADSECPROXY_SERVER_NAME; 
    then
        echo "...Removing the Container"
        exit 1
    fi
}


echo "...creating the Container"

# Remove the container name from any old stopped instances
docker rm $RADSECPROXY_SERVER_NAME >/dev/null 2>/dev/null

# #create the container and allow it to consume up to 50GB of disk for logs
if  ! sudo docker create \
        -p $AUTH_PORT:1812/udp -p $ACCOUNTING_PORT:1813/udp \
        --name $RADSECPROXY_SERVER_NAME \
        --restart always \
        --log-opt max-size=500m --log-opt max-file=100 \
        $IMAGE_NAME;
then
    echo "Failed to create container"
    exit 1
else 
    echo "...created container"
fi

echo "...coping key,certificates and config files to the Container"



# #Copy the key ,Certificates  and the radsecproxy config file


# List=( $RADSEC_KEY_FILE $RADSEC_CRT_FILE $CA_CERT_FILE $RADSEC_CONFIG_FILE )

# LOCATION_MAPPING=( 
#     /etc/ssl/certs/key.pem
#     /etc/ssl/certs/crt.pem 
#     /etc/ssl/certs/cacert.pem
#     /etc/radsecproxy.conf
# )



List=( $RADSEC_KEY_FILE $RADSEC_CRT_FILE $CA_CERT_PATH $RADSEC_CONFIG_FILE )

LOCATION_MAPPING=( 
    /etc/ssl/certs/key.pem
    /etc/ssl/certs/cert.pem 
    /etc/ssl/certs/cacerts
    /etc/radsecproxy.conf
)


for index in ${!List[*]}; 
do 
    if ! sudo docker cp ${List[$index]} $RADSECPROXY_SERVER_NAME:${LOCATION_MAPPING[$index]}; 
    then
        echo "Failed to copy file ${List[$index]}"
        remove_container
        exit 1
    else 
        echo "...copying file  ${List[$index]}"
    fi
done
echo "copy completed!"



#Start the Container 
echo "...starting Radsecproxy container"
if  ! sudo docker start $RADSECPROXY_SERVER_NAME;
then
    echo "Failed to start container"
    remove_container
    exit 1
else 
    echo "...started container"
fi

#Wait for 5 secs to start the container to get the complete logs
sleep 5  # Waits 5 seconds.


#display the logs of the container
echo "RadsecProxy Server Log:"
sudo docker logs $RADSECPROXY_SERVER_NAME


echo "Done"
