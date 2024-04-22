#!/bin/bash
################################################################################
#   Copyright (c) 2020 AT&T Intellectual Property.                             #
#                                                                              #
#   Licensed under the Apache License, Version 2.0 (the "License");            #
#   you may not use this file except in compliance with the License.           #
#   You may obtain a copy of the License at                                    #
#                                                                              #
#       http://www.apache.org/licenses/LICENSE-2.0                             #
#                                                                              #
#   Unless required by applicable law or agreed to in writing, software        #
#   distributed under the License is distributed on an "AS IS" BASIS,          #
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
#   See the License for the specific language governing permissions and        #
#   limitations under the License.                                             #
################################################################################

#set -x

acknowledge() {
  echo "$1"
  read  -n 1 -p "Press any key to continue" mainmenuinput
  echo
}

nodeId="odu-high-tls"
echo "This script demonstrates established connection between ${nodeId} and SDNC(O1 Controller)!"

DIRNAME="/tmp/o1flow-$(date +%Y%m%d%H%M)"
mkdir $DIRNAME
cd $DIRNAME

echo && echo "===> Add network topology node for ${nodeId} in SDNC-SDNR."

# parameters used in API call into SDNC-SDNR
controller="ntust-o1controller.ddns.net"
port="80"
protocol=http
basicAuth="admin:Kp8bJ4SXszM0WXlhak3eHlcse2gAw84vaoGGmJvUy2U"
accept="Accept:application/json"
content="Content-Type:application/json"

echo && acknowledge "Next step: check initial list of nodes configured"
echo "======> Check list of nodes"
path="restconf/config/network-topology:network-topology/topology/topology-netconf"
uri="$protocol://$controller:$port/$path"
echo "curl -u $basicAuth $uri"
curl -s -u $basicAuth $uri | jq .
echo "You should see that pretty an empty list under the \"topology\" array."


echo && echo "======> Prepare config file for the new node"
cat << EOF > oam-connect-${nodeId}.json
{
  "node": [
    {
      "node-id": "$nodeId",
      "netconf-node-topology:host": "140.118.7.31",
      "netconf-node-topology:port": 6513,
      "netconf-node-topology:key-based": {
        "key-id": "ODL_private_key_0",
        "username": "netconf"
      },
      "netconf-node-topology:reconnect-on-changed-schema": false,
      "netconf-node-topology:sleep-factor": 1.5,
      "netconf-node-topology:tcp-only": false,
      "netconf-node-topology:protocol": {"name": "TLS"},
      "netconf-node-topology:connection-timeout-millis": 20000,
      "netconf-node-topology:max-connection-attempts": 100,
      "netconf-node-topology:between-attempts-timeout-millis": 2000,
      "netconf-node-topology:keepalive-delay": 120
    }
  ]
}
EOF
echo "The configuration file is created at: $(pwd)/oam-connect-${nodeId}.json"

echo && echo "======> Create the node"
acknowledge "Next step: create the topology node for ${nodeId}"
path="restconf/config/network-topology:network-topology/topology/topology-netconf"
uri="$protocol://$controller:$port/$path/node/$nodeId"
echo "curl $basicAuth -H $content -H $accept -X PUT -d @./oam-connect-${nodeId}.json $uri" 
curl -i -u $basicAuth -H $content -H $accept -X PUT -d @./oam-connect-${nodeId}.json $uri
echo "As the tradition, a 200 response means that the API call was successful."

echo && acknowledge "Next step: check list of nodes configured"
echo "======> Check list of nodes"
path="restconf/config/network-topology:network-topology/topology/topology-netconf"
uri="$protocol://$controller:$port/$path"
echo "curl -u $basicAuth $uri"
curl -s -u $basicAuth $uri | jq .
echo "You should see that under the \"topology\" array, a node called \"${nodeId}\"."

echo && acknowledge "Next step: check capabilities and supported models of the ${nodeId} node"
echo "======> Querying capabilities and supported models of the ${nodeId} node"
path="restconf/operational/network-topology:network-topology/topology/topology-netconf"
uri="$protocol://$controller:$port/$path"
echo "curl -u $basicAuth $uri"
curl -s -u $basicAuth $uri | jq .
echo "You should see bunch of capabilities advertiised by the ${nodeId} node.  Among which the \"(urn:o-ran:ric:alarm:1.0?revision=2020-01-29)o-ran-sc-ric-alarm-v1\" is what we will use in the demo."

echo && acknowledge "The O1 alarm demonstration is complete.  We now remove the ${nodeId} node to stop the netconf interface between OAM and ${nodeId}"

echo "===> Remove network topology nodee for ${nodeId}"
path="restconf/config/network-topology:network-topology/topology/topology-netconf/node/$nodeId"
uri="$protocol://$controller:$port/$path"
curl -u $basicAuth -X DELETE $uri | jq .
