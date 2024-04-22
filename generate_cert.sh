#/bin/bash
acknowledge() {
    echo "$1"
    read  -n 1 -p "Press any key to continue" mainmenuinput
    echo
}
check_cert_not_exist_in_file(){
    if [ -z "$1" ] || [ -z "$2" ] || [ ! -e "$1" ] || [ ! -e "$2" ] ; then
        false;
        return;
    fi
    file_to_contain="$1";
    file_to_match="$2";
    diff "$file_to_contain" "$file_to_match"|grep -qE '[0-9]+(b|c|d)[0-9]+';
    if [ $? -eq 0 ]; then
          true; # file_to_contain's Cert Not Exist in file_to_match!
          return;
    else
        false; # file_to_contain's Cert Exist in file_to_match!
        return;
    fi
}
rewrite_key_zip(){
    mkdir -p "$SDNR_PATH/certs"
    cd "$SDNR_PATH" && rm -f "$key_name.zip" && zip -qq -r "$key_name.zip" "$key_name/" && mv "$key_name.zip" "certs/$key_name.zip" && cd "$org_pwd";
}
escape_new_line(){
    echo "${1//$'\n'/\\n}"
}
rewrite_private_key(){
    #Check private key exist
    private_key_contents=`cat "$key_folder/$client_filename.key"|sed '/^-----.*/d'`
    client_cert_contents=`cat "$key_folder/$client_filename.crt"|sed '/^-----.*/d'`
    rootCA_contents=`cat rootCA.crt|sed '/^-----.*/d'`
    private_key_contents=`escape_new_line "$private_key_contents"`;
    client_cert_contents=`escape_new_line "$client_cert_contents"`;
    rootCA_contents=`escape_new_line "$rootCA_contents"`;
    if [ -z "$prepare_only" ]; then
        response_code=`curl -so /dev/null -w '%{response_code}' -u "$basicAuth" -X "GET" -H "Content-Type:application/json" -H "Accept:application/json" "$sdnc_controller/rests/data/netconf-keystore:keystore/private-key=$private_key_name"`
        if [ "$response_code" -eq "200" ]; then #Clean
            curl -u "$basicAuth" -X "DELETE" "$sdnc_controller/rests/data/netconf-keystore:keystore/private-key=$private_key_name"
        fi
        # PUT:
        # {"private-key": [
        #     {
        #     "name": "ODL_private_key_0",
        #     "data": "private key",
        #     "certificate-chain": [
        #             "server cert",
        #             "rootCA cert"
        #     ]
        #     }
        # ]}
        curl -s -u "$basicAuth" -H "Content-Type:application/json" -H "Accept:application/json" -X "PUT" "$sdnc_controller/rests/data/netconf-keystore:keystore/private-key=$private_key_name" --data "{"'"'"private-key"'"'": [{"'"'"name"'"'": "'"'"$private_key_name"'"'", "'"'"data"'"'": "'"'"$private_key_contents"'"'", "'"'"certificate-chain"'"'": ["'"'"$client_cert_contents"'"'", "'"'"$rootCA_contents"'"'"]}]}"
    fi
}
current_folder="$(dirname -- "$0")"
org_pwd="$(pwd)"
# Step 1: Generate Client certificate for SDNC
SDNR_PATH="$current_folder/sdnr"
key_name="keys0"
key_folder="$SDNR_PATH/$key_name"
if [ ! -e "$key_folder" ]; then
    mkdir -p "$key_folder"
fi
certs_changed=""
email_field="exampleclient@localhost"
country_name="CZ" #"TW"
state_name="South Moravia" #"A" #ex: A => Taipei, https://en.wikipedia.org/wiki/National_identification_card_(Taiwan)
organization_name="CESNET" #"NTUST"
organization_unit="TMC"
common_name="example client" #sometimes use Domain name
subject_for_sdnc="/C=$country_name/ST=$state_name/O=$organization_name/OU=$organization_unit/CN=$common_name/emailAddress=$email_field"
subject_for_rootCA="/C=$country_name/ST=$state_name/O=$organization_name/OU=$organization_unit/CN=root ca"
expiration_days=500
sdnc_controller="https://ntust-sdnc.ddns.net"
basicAuth="admin:Kp8bJ4SXszM0WXlhak3eHlcse2gAw84vaoGGmJvUy2U"
server_node_name="odu-high" #ODU-HIGH
private_key_name="ODL_private_key_0"
subject_for_server="/C=$country_name/ST=$state_name/O=$organization_name/CN=$server_node_name"
client_filename="client"
server_filename="server"
force_resign="0"
force_resign_server="0"
force_fix="1"
prepare_only=""
if [[ "$1" == "--prepare" ]]; then
    prepare_only="1"
fi
if [ -e "$SDNR_PATH/certs/$key_name.zip" ]; then
    cd "$SDNR_PATH" && unzip -qq -o "certs/$key_name.zip" && cd "$org_pwd"
fi
if [ ! -e "$key_folder/trustedCertificates.crt" ]; then
    touch "$key_folder/trustedCertificates.crt"
fi
if [ ! -e rootCA.key ]; then
    openssl genrsa -out rootCA.key 4096
fi
if [ ! -e rootCA.crt ]; then
    openssl req -x509 -new -nodes -key rootCA.key -subj "$subject_for_rootCA" -sha256 -days $((expiration_days * 2)) -out rootCA.crt
fi
if [ ! -e "$key_folder/$client_filename.key" ]; then
    openssl genrsa -out "$key_folder/$client_filename.key" 2048
    openssl req -new -sha256 -key "$key_folder/$client_filename.key" -subj "$subject_for_sdnc" -out "$key_folder/$client_filename.csr" # Generate rsa cert request
    openssl x509 -req -in "$key_folder/$client_filename.csr" -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out "$key_folder/$client_filename.crt" -days 500 -sha256 # Signed cert with rootCA
    echo "$client_filename.key and $client_filename.crt generated!"
    certs_changed="1"
else
    if [ ! -e "$key_folder/$client_filename.crt" ] || [ "$force_resign" -eq "1" ]; then
        openssl req -new -sha256 -key "$key_folder/$client_filename.key" -subj "$subject_for_sdnc" -out "$key_folder/$client_filename.csr" -config client_req.conf # Generate rsa cert request
        openssl x509 -req -extensions v3_req -in "$key_folder/$client_filename.csr" -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out "$key_folder/$client_filename.crt" -days 500 -sha256 -extfile client_req.conf # Signed cert with rootCA
        echo "$client_filename.crt generated!"
        certs_changed="1"
    fi
fi
rewrite_private_key;
rewrite_key_zip;
mkdir -p "$SDNR_PATH/certs"
echo -e "$key_name.zip\n*****" > "$SDNR_PATH/certs/certs.properties" #certs.properties now support only single zip file.
# Step 2: Generate Server certificate and xml file
if [ "$force_resign_server" -eq "1" ] || [ ! -e "keystore.xml" ]; then
    if [ ! -e "$key_folder/$server_filename.key" ]; then
        openssl genrsa -out "$server_filename.key" 2048 # Generate rsa private key
        openssl rsa -in "$server_filename.key" -out "$server_filename.pem" -pubout -outform PEM #Generate rsa public key
        openssl req -new -sha256 -key "$server_filename.key" -subj "$subject_for_server" -out "$server_filename.csr" -config server_req.conf # Generate rsa cert request
        openssl x509 -req -sha256 -extensions v3_req -in "$server_filename.csr" -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out "$server_filename.crt" -days $expiration_days -extfile server_req.conf # Generate rsa cert
        echo "$server_filename.key and $server_filename.crt generated!"
        certs_changed="1"
    else
        if [ ! -e "$key_folder/$server_filename.crt" ] || [ "$force_resign" -eq "1" ]; then
            openssl rsa -in "$server_filename.key" -out "$server_filename.pem" -pubout -outform PEM #Generate rsa public key
            openssl req -new -sha256 -key "$server_filename.key" -subj "$subject_for_server" -out "$server_filename.csr" -config server_req.conf  # Generate rsa cert request
            openssl x509 -req -sha256 -extensions v3_req -in "$server_filename.csr" -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out "$server_filename.crt" -days $expiration_days -extfile server_req.conf # Generate rsa cert
            echo "$server_filename.crt generated!"
            certs_changed="1"
        else
            openssl rsa -in "$server_filename.key" -out "$server_filename.pem" -pubout -outform PEM #Generate rsa public key
        fi
    fi 
    rsa_server_priv_key=`cat "$server_filename.key" |sed '/^-----.*/d'|tr -d '\n'`
    rsa_server_pub_key=`cat "$server_filename.pem" |sed '/^-----.*/d'|tr -d '\n'`
    rsa_server_crt_64=`cat "$server_filename.crt" |sed '/^-----.*/d'`
    rsa_server_crt=`echo "$rsa_server_crt_64"|tr -d '\n'`
    cat << EOF > keystore.xml
<keystore xmlns="urn:ietf:params:xml:ns:yang:ietf-keystore">
    <asymmetric-keys>
        <asymmetric-key>
            <name>serverkey</name>
            <algorithm>rsa2048</algorithm>
            <public-key>$rsa_server_pub_key</public-key>
            <private-key>$rsa_server_priv_key</private-key>
            <certificates>
                <certificate>
                    <name>servercert</name>
                    <cert>$rsa_server_crt</cert>
                </certificate>
            </certificates>
        </asymmetric-key>
    </asymmetric-keys>
</keystore>
EOF
    echo "keystore.xml generated!"
else
    rsa_server_crt=`grep '<cert>' keystore.xml |sed -E 's/^\s*<cert>//g'|sed -E 's/<\/cert>//g'`
    rsa_server_crt_64=`echo "$rsa_server_crt"|sed -E 's/.{64}/\0\n/g'`
    echo '-----BEGIN CERTIFICATE-----' > "$server_filename.crt"
    echo "$rsa_server_crt_64" >> "$server_filename.crt"
    echo '-----END CERTIFICATE-----' >> "$server_filename.crt"
fi
rsa_server_crt_64="${rsa_server_crt_64//$'\n'/\\n}"
if [ "$prepare_only" == "1" ]; then
    if check_cert_not_exist_in_file "$server_filename.crt" "$key_folder/trustedCertificates.crt"; then
        x=$(tail -c 1 "$key_folder/trustedCertificates.crt")
        if [ "$x" != "" ]; then
            echo "" >> "$key_folder/trustedCertificates.crt"; #Add newline if last character exist
        fi
        cat "$server_filename.crt" >> "$key_folder/trustedCertificates.crt";
        rewrite_key_zip;
    fi
else
    has_added_trusted=`curl -s -u "$basicAuth" "$sdnc_controller/restconf/config/netconf-keystore:keystore"|jq '.keystore."trusted-certificate"| to_entries[]| select(.value.name == "'$server_node_name'")| select(.value.certificate == "'$rsa_server_crt_64'")'`
    if [ -z "$has_added_trusted" ]; then #Cert not in trust certificates
        # Check node $server_node_name exist in netconf topology
        topology_list=`curl -s -u $basicAuth "$sdnc_controller/restconf/config/network-topology:network-topology/topology/topology-netconf"`
        node_exist_in_topology=`echo $topology_list|jq '.topology| to_entries[]| select(.value."topology-id" == "topology-netconf")| .value.node| to_entries[]| select(.value."node-id" == "'$server_node_name'")' 2>/dev/null`
        if [ -z "$node_exist_in_topology" ]; then
            curl -s -u "$basicAuth" -H "Content-Type:application/json" -H "Accept:application/json" -X "PUT" "$sdnc_controller/restconf/config/network-topology:network-topology/topology/topology-netconf/node/$server_node_name" --data '{"node": [{"node-id": "'$server_node_name'"}]}'
            echo "Node $server_node_name added!"
        else
            echo "Node $server_node_name detected!"
        fi
        old_cert=`curl -s -u "$basicAuth" -H "Content-Type:application/json" -H "Accept:application/json" -X "GET" "$sdnc_controller/rests/data/netconf-keystore:keystore/trusted-certificate=$server_node_name"|jq '."netconf-keystore:trusted-certificate"| to_entries[]| .value.certificate' 2>/dev/null`
        if [ ! -z "$old_cert" ]; then
            old_cert="${old_cert:1:-1}"
            echo 'old cert found!'
            curl -s -u "$basicAuth" -H "Content-Type:application/json" -H "Accept:application/json" -X "DELETE" "$sdnc_controller/rests/data/netconf-keystore:keystore/trusted-certificate=$server_node_name"
            matched_line_nums=$(grep -wn "${old_cert//\\n/$'\n'}" "$key_folder/trustedCertificates.crt"|cut -d ':' -f 1|xargs)
            if [ ! -z "$matched_line_nums" ]; then
                old_cert_line_start=`echo "${matched_line_nums// /$'\n'}"|head -n1`;
                old_cert_line_end=`echo "${matched_line_nums// /$'\n'}"|tail -n1`;
                trustedCertificates_contents=`cat "$key_folder/trustedCertificates.crt" | awk '{if (NR<'$((old_cert_line_start - 1))' || NR >'$((old_cert_line_end + 1))') print}'`;
                echo "$trustedCertificates_contents" > "$key_folder/trustedCertificates.crt";
            fi
        fi
        curl -s -u "$basicAuth" -H "Content-Type:application/json" -H "Accept:application/json" -X "POST" "$sdnc_controller/rests/data/netconf-keystore:keystore/trusted-certificate=$server_node_name" --data "{'certificate': '$rsa_server_crt_64'}"
        if check_cert_not_exist_in_file "$server_filename.crt" "$key_folder/trustedCertificates.crt"; then
            x=$(tail -c 1 "$key_folder/trustedCertificates.crt")
            if [ "$x" != "" ]; then
                echo "" >> "$key_folder/trustedCertificates.crt"; #Add newline if last character exist
            fi
            cat "$server_filename.crt" >> "$key_folder/trustedCertificates.crt";
            rewrite_key_zip;
        fi
        echo "Trust Certificate for $server_node_name added!"
    else
        echo "Trust Certificate for $server_node_name detected!"    
    fi
fi
if [ "$force_fix" == "1" ] || [ "$certs_changed" == "1" ] || [ ! -e "truststore.xml" ]; then
    rsa_client_crt=`cat "$key_folder/client.crt" |sed '/^-----.*/d'| tr -d '\n'`
    rsa_rootCA_crt=`cat rootCA.crt |sed '/^-----.*/d'| tr -d '\n'`
    cat << EOF > truststore.xml
<truststore xmlns="urn:ietf:params:xml:ns:yang:ietf-truststore">
    <certificates>
        <name>clientcerts</name>
        <certificate>
            <name>clientcert</name>
            <cert>$rsa_client_crt</cert>
        </certificate>
    </certificates>
    <certificates>
        <name>cacerts</name>
        <certificate>
            <name>cacert</name>
            <cert>$rsa_rootCA_crt</cert>
        </certificate>
    </certificates>
</truststore>
EOF
    echo "truststore.xml generated!"
fi
if [ "$force_fix" == "1" ] || [ "$force_resign_server" -eq "1" ] || [ "$force_resign" -eq "1" ] || [ "$certs_changed" == "1" ] || [ ! -e "netconf_server_tls.xml" ]; then
    # Reference fingerprint enum: https://datatracker.ietf.org/doc/html/rfc5246#page-72
    # Ex: 02 => sha1
    client_sha1_fingerprint=`openssl x509 -noout -fingerprint -sha1 -inform pem -in "$key_folder/client.crt"|sed -E 's/^[^\=]+\=//g'`
    rootca_sha1_fingerprint=`openssl x509 -noout -fingerprint -sha1 -inform pem -in "rootCA.crt"|sed -E 's/^[^\=]+\=//g'`
    cat << EOF > netconf_server_tls.xml
<netconf-server xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-server">
    <listen>
        <endpoint>
            <name>default-tls</name>
            <tls>
                <tcp-server-parameters>
                    <local-address>::</local-address>
                    <local-port>6513</local-port>
                    <keepalives>
                        <idle-time>1</idle-time>
                        <max-probes>10</max-probes>
                        <probe-interval>5</probe-interval>
                    </keepalives>
                </tcp-server-parameters>
                <tls-server-parameters>
                    <server-identity>
                        <keystore-reference>
                            <asymmetric-key>serverkey</asymmetric-key>
                            <certificate>servercert</certificate>
                        </keystore-reference>
                    </server-identity>
                    <client-authentication>
                        <required/>
                        <ca-certs>cacerts</ca-certs>
                        <client-certs>clientcerts</client-certs>
                        <cert-maps>
                            <cert-to-name>
                                <id>1</id>
                                <fingerprint>02:$rootca_sha1_fingerprint</fingerprint>
                                <map-type xmlns:x509c2n="urn:ietf:params:xml:ns:yang:ietf-x509-cert-to-name">x509c2n:specified</map-type>
                                <name>root-ca-mapping</name>
                            </cert-to-name>
                        </cert-maps>
                    </client-authentication>
                </tls-server-parameters>
            </tls>
        </endpoint>
    </listen>
</netconf-server>
EOF
#     cat << EOF > netconf_server_tls.xml
# <netconf-server xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-server">
#     <listen>
#         <endpoint>
#             <name>default-tls</name>
#             <tls>
#                 <tcp-server-parameters>
#                     <local-address>::</local-address>
#                     <local-port>6513</local-port>
#                     <keepalives>
#                         <idle-time>1</idle-time>
#                         <max-probes>10</max-probes>
#                         <probe-interval>5</probe-interval>
#                     </keepalives>
#                 </tcp-server-parameters>
#                 <tls-server-parameters>
#                     <server-identity>
#                         <keystore-reference>
#                             <asymmetric-key>serverkey</asymmetric-key>
#                             <certificate>servercert</certificate>
#                         </keystore-reference>
#                     </server-identity>
#                     <client-authentication>
#                         <required/>
#                         <ca-certs>cacerts</ca-certs>
#                         <client-certs>clientcerts</client-certs>
#                         <cert-maps>
#                             <cert-to-name>
#                                 <id>1</id>
#                                 <fingerprint>02:$client_sha1_fingerprint</fingerprint>
#                                 <map-type xmlns:x509c2n="urn:ietf:params:xml:ns:yang:ietf-x509-cert-to-name">x509c2n:specified</map-type>
#                                 <name>sdnc-cert-mapping</name>
#                             </cert-to-name>
#                             <cert-to-name>
#                                 <id>2</id>
#                                 <fingerprint>02:$rootca_sha1_fingerprint</fingerprint>
#                                 <map-type xmlns:x509c2n="urn:ietf:params:xml:ns:yang:ietf-x509-cert-to-name">x509c2n:specified</map-type>
#                                 <name>root-ca-mapping</name>
#                             </cert-to-name>
#                         </cert-maps>
#                     </client-authentication>
#                 </tls-server-parameters>
#             </tls>
#         </endpoint>
#     </listen>
# </netconf-server>
# EOF
    echo "netconf_server_tls.xml generated!"
fi
