# SDNC TLS Configure

## Startup

```bash
git clone https://git-ntustoran.ddns.net/oran/sdnc-tls-configure
# Edit generate_cert.sh
# Replace if needed
# sdnc_controller="https://ntust-sdnc.ddns.net"
# basicAuth="admin:Kp8bJ4SXszM0WXlhak3eHlcse2gAw84vaoGGmJvUy2U"
# server_node_name="odu-high"
# private_key_name="ODL_private_key_0"
# SDNR_PATH="$current_folder/sdnr"
# key_name="keys0"
# key_folder="$SDNR_PATH/$key_name"

# Edit netconf_server_configure.sh
# sdnc_controller="https://ntust-sdnc.ddns.net"
# basicAuth="admin:Kp8bJ4SXszM0WXlhak3eHlcse2gAw84vaoGGmJvUy2U"
# SDNR_PATH="$current_folder/sdnr"
# key_name="keys0"
# key_folder="$SDNR_PATH/$key_name"
```

## Setup for SDNC(outside container)

```bash
# $ ./clean_certs.sh #Clean server certificates and xml files for netconf server
$ ./generate_cert.sh # Generate files and call rest api to add trust certificates and private key.
# $ ./generate_cert.sh --prepare # Only generate files, not call rest api to add trust certificates and private key.
# ./sdnr/certs/ folder can be mounted into sdnc container:/opt/opendaylight/current/certs/
# In osc oam project, sdnc may be called sdnr
# In $OAM_DIR/solution/integration/smo/oam/docker-compose.yml
# volumes:
#      - ./sdnr/certs/certs.properties:${SDNC_CERT_DIR}/certs.properties
#      - ./sdnr/certs/keys0.zip:${SDNC_CERT_DIR}/keys0.zip

# $ ./clean_certs.sh #Clean server certificates and xml files for netconf server
```

## Setup for Netconf Server(in container or the same environ as netopeer2-server)

```bash
# Exec generate_cert.sh in client and
# Copy keystore.xml, truststore.xml, netconf_server_tls.xml to server
# Ex: cp keystore.xml $dest_dir/.
# Ex: docker cp keystore.xml "$container:/root/keystore.xml"
# Ex: kubectl cp keystore.xml deployment-ricplt-o1mediator-c8d5db5c7-9p9ps:/root/keystore.xml
# For o1meidator kubenetes:
# $ ./o1mediator_configure.sh #call kubectl to exec commands in pod.
$ ./netconf_server_configure.sh #Ex: for odu-high. (xml files and script in the same folder)
```

## Establish TLS Connections

```bash
# You can edit connection info of SDNC in script
# controller="ntust-o1controller.ddns.net"
# port="80"
# protocol=http
# nodeId="near-rt-ric-01"
# basicAuth="admin:Kp8bJ4SXszM0WXlhak3eHlcse2gAw84vaoGGmJvUy2U"

# For odu-high
# Edit ./demos/odu-high-tls.sh
# Edit odu-high info:
# line 26: nodeId="odu-high-tls"
# line 58: "netconf-node-topology:host": "140.118.7.31",
# line 59: "netconf-node-topology:port": 6513
$ ./demos/odu-high-tls.sh

# For o1mediator
# Edit ./demos/o1mediator-tls.sh
# Edit o1mediator info:
# line 40: nodeId="near-rt-ric-01"
# line 60: "netconf-node-topology:host": "140.118.7.31",
# line 61: "netconf-node-topology:port": 30513
$ ./demos/o1mediator-tls.sh

# You can use sdnc-web gui to check whether the connections are successful.
# https://ntust-sdnc.ddns.net/odlux/index.html#/connect
```

## List of file Generated

1. keystore.xml

   Store certificates and private key for Netconf Server.

2. truststore.xml

   Store trusted certificates, including Netconf client and rootCA certificates.

3. netconf_server_tls.xml

   Netconf Server TLS configure file. Including listen address and port setting. keystore-reference part represents which key pair referenced from keystore. cert-to-name part is for client authentication. We can put only the rootCA fingerprint in cert-to-name. fingerprint prefix represents which hash algorithm is chosen. For instance, 02 is SHA1.

   More detail for fingerprint enum: https://datatracker.ietf.org/doc/html/rfc5246#page-72

4. server.key

   RSA private key for Netconf server.

5. server.csr

   Certificate Signing Request for Netconf server.

6. server.pem

   RSA public key for Netconf server.

7. server.crt

   Certificate file for Netconf Server.

8. sdnr/keys0 folder

   Store client private key and client certificate and trustedCertificates.

9. sdnr/certs/certs.properties
   ```txt
   keys0.zip
   *****
   ```

   Supported single zip file now.

   Mount to /opt/opendaylight/current/certs/certs.properties

10. sdnr/certs/keys0.zip

    It will be installed when container is initializing.

    Mount to /opt/opendaylight/current/certs/keys0.zip
