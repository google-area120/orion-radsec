#!/bin/sh

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
#  These values may need some tuning based on observations. They support the
#  tests which aim to restart radsecproxy in the event of a memory leak before
#  the system is driven into swap.
#
MAX_VM_SIZE=1024000
MAX_VM_RSS=256000


#
#  If a user is shelled into the container then we still run the checks but
#  always conclude with a good exit status to mark the container as healthy so
#  that we don't pull the rug from under a debugging session.
#
BAD_EXIT=1
pgrep -af /bin/sh | cut -f 2- -d ' ' | grep -Fxq '/bin/sh' && BAD_EXIT=0


#
#  Extract some variables from the radsecproxy configuration
#
SECRET=$(sed -ne 's/^\s*secret\s\+\(.\+\)$/\1/p' /etc/radsecproxy.conf | sed -e 's/^"\(.*\)"$/\1/')
RADSEC_SECRET=radsec
RADSEC_IP=$(sed -ne '/^server.*{/,/^}/p' /etc/radsecproxy.conf | sed -ne 's/^\s*host\s\+\(.\+\)$/\1/p' | sed -e 's/^"\(.*\)"$/\1/')
RADSEC_PORT=$(sed -ne '/^server.*{/,/^}/p' /etc/radsecproxy.conf | sed -ne 's/^\s*port\s\+\(.\+\)$/\1/p' /etc/radsecproxy.conf | sed -e 's/^"\(.*\)"$/\1/')
CACERTPATH=$(sed -ne '/^tls.*{/,/^}/p' /etc/radsecproxy.conf | sed -ne 's/^\s*CACertificatePath\s\+\(.\+\)$/\1/p' | sed -e 's/^"\(.*\)"$/\1/')
CERT=$(sed -ne '/^tls.*{/,/^}/p' /etc/radsecproxy.conf | sed -ne 's/^\s*CertificateFile\s\+\(.\+\)$/\1/p' | sed -e 's/^"\(.*\)"$/\1/')
KEY=$(sed -ne '/^tls.*{/,/^}/p' /etc/radsecproxy.conf | sed -ne 's/^\s*CertificateKeyFile\s\+\(.\+\)$/\1/p' | sed -e 's/^"\(.*\)"$/\1/')


############################################
#  Local tests on the radsecproxy process  #
############################################

#
#  Process is no longer running (e.g. become a zombie)
#
pkill -0 radsecproxy 2>/dev/null || { echo -n "radsecproxy process is not running"; exit $BAD_EXIT; }


#
#  VmSize > 768MB is too high
#
VM_SIZE=$(sed -ne 's/^VmSize:[[:space:]]\+\([[:digit:]]\+\) kB$/\1/p' /proc/`pgrep -P 1 radsecproxy`/status)
[ "$VM_SIZE" -lt "$MAX_VM_SIZE" ] || { echo -n "radsecproxy process excessive virtual memory: $VM_SIZE kB"; exit $BAD_EXIT; }

#
#  VmRSS > 256MB is too high
#
VM_RSS=$(sed -ne 's/^VmRSS:[[:space:]]\+\([[:digit:]]\+\) kB$/\1/p' /proc/`pgrep -P 1 radsecproxy`/status)
[ "$VM_RSS" -lt "$MAX_VM_RSS" ] || { echo -n "radsecproxy process excessive resident set: $VM_RSS kB"; exit $BAD_EXIT; }


#
#  Status requests are satisfied by the local radsecproxy
#
echo "Message-Authenticator = 0x00" | radclient -r 1 127.0.0.1 status "$SECRET" >/dev/null || {
  echo -n "radsecproxy did not respond to a local Server-Status request. Local process hang?"; exit $BAD_EXIT;
}


#####################################################
#  Check connectivity to the remote RadSec service  #
#####################################################

#
#  This is an informational test that performs a status-server request
#  directly to the RadSec endpoint using stunnel to set up the TLS
#  connection.
#
#  We don't fail the healthcheck (leading to container restart) just
#  because we can't connect since a network connectivity or certificate
#  issue is unlikely to be resolved by merely restarting the container.
#
#  Nevertheless the output of the test may be useful for diagnostics.
#

#  NOTE: This check is currently disabled because not all RadSec endpoints are
#  responding to Status-Server requests.

#pkill -9 stunnel || true
#sleep 1
#cat <<EOF | stunnel -fd 0 &
#foreground = yes
#socket = l:TCP_NODELAY=1
#socket = r:TCP_NODELAY=1
#debug = 4
#client = yes
#cert = $CERT
#key = $KEY
#
#[radsec]
#accept  = 127.0.0.1:12083
#connect = $RADSEC_IP:$RADSEC_PORT
#CApath = $CACERTPATH
#verify = 2
#verifyChain = yes
#checkIP = $RADSEC_IP
#EOF
#
#stunnelpid=$!
#sleep 1
#
#echo "Message-Authenticator = 0x00" | radclient -q -r 1 -P tcp 127.0.0.1:12083 status "$RADSEC_SECRET" || {
#  echo -n "Remote RadSec service did not respond to a direct Server-Status request. Poor connectivity or bad certificates: Running no further checks."
#  kill $stunnelpid
#  exit 0;
#}
#kill $stunnelpid


##########
#  Done  #
##########

echo "Tests completed successfully."
exit 0
